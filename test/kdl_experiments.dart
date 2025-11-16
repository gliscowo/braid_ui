import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'package:big_decimal/big_decimal.dart';
import 'package:braid_ui/braid_ui.dart';
import 'package:collection/collection.dart';
import 'package:endec/endec.dart';
import 'package:endec_json/endec_json.dart';
import 'package:kdl/kdl.dart';
import 'package:logging/logging.dart';

typedef KdlMapper = ({
  bool export,
  String key,
  KdlElement Function(KdlNode node) get,
  void Function(KdlNode node, KdlElement element) set,
});

final defaultKdlMappers = UnmodifiableListView([
  (
    export: true,
    key: '@name',
    get: (node) => KdlValueElement(KdlString(node.name)),
    set: (node, element) => node.name = (element as KdlValueElement).value.value as String,
  ),
  (
    export: false,
    key: '@argument',
    get: (node) => KdlValueElement(node.arguments.first),
    set: (node, element) => node.arguments.first = (element as KdlValueElement).value,
  ),
  (
    export: true,
    key: '@arguments',
    get: (node) => KdlElementList(node.arguments.map<KdlElement>(KdlValueElement.new).toList()),
    set: (node, element) =>
        node.arguments = (element as KdlElementList).elements.map((e) => (e as KdlValueElement).value).toList(),
  ),
  (
    export: false,
    key: '@child',
    get: (node) => KdlNodeElement(node.children.first),
    set: (node, element) => node.children.first = (element as KdlNodeElement).node,
  ),
  (
    export: true,
    key: '@children',
    get: (node) {
      return KdlElementList(node.children.map<KdlElement>(KdlNodeElement.new).toList());
    },
    set: (node, element) =>
        node.children = (element as KdlElementList).elements.map((e) => (e as KdlNodeElement).node).toList(),
  ),
]);

T fromKdl<T>(Endec<T> endec, KdlNode node, {List<KdlMapper>? mappers, SerializationContext? ctx}) {
  ctx ??= SerializationContext(attributes: [humanReadable]);

  final deserializer = KdlDeserializer(node, mappers ?? defaultKdlMappers);
  return endec.decode(ctx, deserializer);
}

sealed class KdlElement {}

final class KdlElementList extends KdlElement {
  final List<KdlElement> elements;
  KdlElementList(this.elements);
}

final class KdlNodeElement extends KdlElement {
  final KdlNode node;
  KdlNodeElement(this.node);
}

final class KdlValueElement extends KdlElement {
  final KdlValue value;
  KdlValueElement(this.value);
}

class KdlDeserializer extends RecursiveDeserializer<KdlElement> implements SelfDescribingDeserializer {
  final List<KdlMapper> mappers;

  KdlDeserializer(KdlNode rootNode, this.mappers) : super(KdlNodeElement(rootNode));

  @override
  void any(SerializationContext ctx, Serializer visitor) => _decodeElement(ctx, visitor, currentValue(ctx));

  late final _elementEndec = Endec<KdlElement>.of(
    _decodeElement,
    (ctx, deserializer) => throw StateError('unreachable'),
  );

  void _decodeElement(SerializationContext ctx, Serializer visitor, KdlElement element) {
    switch (element) {
      case KdlValueElement(:var value):
        switch (value.value) {
          case bool value:
            visitor.boolean(ctx, value);
          case int value:
            visitor.i64(ctx, value);
          case BigDecimal value:
            visitor.f64(ctx, value.toDouble());
          case String value:
            visitor.string(ctx, value);
          case _:
            throw UnimplementedError();
        }
      case KdlNodeElement(:var node):
        final state = visitor.struct();
        for (final MapEntry(:key, :value) in node.properties.entries) {
          state.field(key, ctx, _elementEndec, KdlValueElement(value));
        }
        for (final mapper in mappers.where((element) => element.export)) {
          state.field(mapper.key, ctx, _elementEndec, mapper.get(node));
        }
        state.end();
      case KdlElementList(:var elements):
        final state = visitor.sequence(ctx, _elementEndec, elements.length);
        for (final element in elements) {
          state.element(element);
        }
        state.end();
    }
  }

  @override
  int i8(SerializationContext ctx) => _expectPrimitive(ctx);
  @override
  int u8(SerializationContext ctx) => _expectPrimitive(ctx);

  @override
  int i16(SerializationContext ctx) => _expectPrimitive(ctx);
  @override
  int u16(SerializationContext ctx) => _expectPrimitive(ctx);

  @override
  int i32(SerializationContext ctx) => _expectPrimitive(ctx);
  @override
  int u32(SerializationContext ctx) => _expectPrimitive(ctx);

  @override
  int i64(SerializationContext ctx) => _expectPrimitive(ctx);
  @override
  int u64(SerializationContext ctx) => _expectPrimitive(ctx);

  @override
  double f32(SerializationContext ctx) => _expectPrimitive<BigDecimal>(ctx).toDouble();
  @override
  double f64(SerializationContext ctx) => _expectPrimitive<BigDecimal>(ctx).toDouble();

  @override
  bool boolean(SerializationContext ctx) => _expectPrimitive(ctx);
  @override
  String string(SerializationContext ctx) => _expectPrimitive(ctx);
  @override
  Uint8List bytes(SerializationContext ctx) => throw UnimplementedError();
  @override
  E? optional<E>(SerializationContext ctx, Endec<E> endec) => endec.decode(ctx, this);

  V _expectPrimitive<V>(SerializationContext ctx) {
    final value = currentValue<KdlValueElement>(ctx).value.value;
    if (value is V) {
      return value;
    } else {
      ctx.malformedInput('Expected a $V, got a ${value.runtimeType}');
    }
  }

  @override
  SequenceDeserializer<E> sequence<E>(SerializationContext ctx, Endec<E> elementEndec) =>
      _KdlSequenceDeserializer(this, ctx, elementEndec, currentValue<KdlElementList>(ctx).elements);
  @override
  MapDeserializer<V> map<V>(SerializationContext ctx, Endec<V> valueEndec) => throw UnimplementedError();
  @override
  StructDeserializer struct(SerializationContext ctx) =>
      _KdlStructDeserializer(this, currentValue<KdlNodeElement>(ctx).node);
}

class _KdlStructDeserializer implements StructDeserializer {
  final KdlDeserializer deserializer;
  final KdlNode node;

  _KdlStructDeserializer(this.deserializer, this.node);

  @override
  F field<F>(String name, SerializationContext ctx, Endec<F> endec, {F Function()? defaultValueFactory}) {
    var element = _tryMap(name);
    if (element == null && node.properties.containsKey(name)) {
      element = KdlValueElement(node.properties[name]!);
    }

    if (element == null) {
      if (defaultValueFactory != null) return defaultValueFactory();
      ctx.malformedInput('Required property $name is missing from serialized data');
    }

    return deserializer.frame(
      () => element!,
      () => endec.decode(ctx.pushField(node.name).pushField(name), deserializer),
    );
  }

  KdlElement? _tryMap(String key) {
    final mapper = deserializer.mappers.firstWhereOrNull((element) => element.key == key);
    if (mapper == null) return null;

    final element = mapper.get(node);
    return element;
  }
}

class _KdlSequenceDeserializer<V> implements SequenceDeserializer<V> {
  final KdlDeserializer deserializer;
  final SerializationContext ctx;
  final Endec<V> elementEndec;
  final Iterator<(int, KdlElement)> iterator;

  _KdlSequenceDeserializer(this.deserializer, this.ctx, this.elementEndec, List<KdlElement> elements)
    : iterator = elements.indexed.iterator;

  @override
  bool moveNext() => iterator.moveNext();

  @override
  V element() => deserializer.frame(
    () => iterator.current.$2,
    () => elementEndec.decode(ctx.pushIndex(iterator.current.$1), deserializer),
  );
}

final widgetEndecRegistry = <String, StructEndec<Widget>>{};
final widgetTypeNameRegistry = <Type, String>{};

final widgetEndec = Endec.dispatchedStruct<Widget, String>(
  (variant) {
    final endec = widgetEndecRegistry[variant];
    if (endec == null) {
      throw 'unknown widget type: $variant';
    }

    return endec;
  },
  (instance) => widgetTypeNameRegistry[instance.runtimeType]!,
  Endec.string,
  key: '@name',
);

void registerWidgetEndec<W extends Widget>(
  String key,
  StructEndec<W> Function(StructEndecBuilder<W> builder) builderFn,
) {
  final endec = builderFn(structEndec<W>());
  widgetEndecRegistry[key] = endec;
  widgetTypeNameRegistry[W] = key;
}

final handlersAttribute = ValueAttribute<Map<String, Function>>('braid_handlers');

Future<void> main() async {
  registerWidgetEndec('_empty', (builder) => StructEndec.of((_, _, _, _) {}, (_, _, _) => const EmptyWidget()));

  final alignmentEndec = Endec.string.xmap(
    (self) => switch (self) {
      'top' => Alignment.top,
      'bottom' => Alignment.bottom,
      'left' => Alignment.left,
      'right' => Alignment.right,
      'top_left' => Alignment.topLeft,
      'top_right' => Alignment.topRight,
      'bottom_left' => Alignment.bottomLeft,
      'bottom_right' => Alignment.bottomRight,
      'center' => Alignment.center,
      _ => throw UnimplementedError(),
    },
    (_) => throw UnimplementedError(),
  );

  registerWidgetEndec<Align>(
    'align',
    (builder) => builder.with2Fields(
      alignmentEndec.fieldOf('@argument', (struct) => struct.alignment),
      widgetEndec.fieldOf('@child', (struct) => struct.child),
      (alignment, child) => Align(alignment: alignment, child: child),
    ),
  );

  registerWidgetEndec<Center>(
    'center',
    (builder) =>
        builder.with1Field(widgetEndec.fieldOf('@child', (struct) => struct.child), (child) => Center(child: child)),
  );

  registerWidgetEndec<Padding>(
    'padding',
    (builder) => builder.with8Fields(
      Endec.f32.optionalOf().fieldOf('@argument', (struct) => null, defaultValueFactory: () => null),
      Endec.f32.optionalOf().fieldOf('horizontal', (struct) => null, defaultValueFactory: () => null),
      Endec.f32.optionalOf().fieldOf('vertical', (struct) => null, defaultValueFactory: () => null),
      Endec.f32.optionalOf().fieldOf('top', (struct) => struct.insets.top, defaultValueFactory: () => null),
      Endec.f32.optionalOf().fieldOf('bottom', (struct) => struct.insets.bottom, defaultValueFactory: () => null),
      Endec.f32.optionalOf().fieldOf('left', (struct) => struct.insets.left, defaultValueFactory: () => null),
      Endec.f32.optionalOf().fieldOf('right', (struct) => struct.insets.right, defaultValueFactory: () => null),
      widgetEndec.optionalOf().fieldOf('@child', (struct) => struct.child, defaultValueFactory: () => null),
      (all, horizontal, vertical, top, bottom, left, right, child) {
        top ??= vertical ?? all ?? 0;
        bottom ??= vertical ?? all ?? 0;
        left ??= vertical ?? all ?? 0;
        right ??= vertical ?? all ?? 0;

        return Padding(
          insets: Insets(top: top, bottom: bottom, left: left, right: right),
          child: child,
        );
      },
    ),
  );

  registerWidgetEndec<Sized>(
    'sized',
    (builder) => builder.with3Fields(
      Endec.f32.optionalOf().fieldOf('width', (struct) => struct.width, defaultValueFactory: () => null),
      Endec.f32.optionalOf().fieldOf('height', (struct) => struct.height, defaultValueFactory: () => null),
      widgetEndec.fieldOf('@child', (struct) => struct.child),
      (width, height, child) => Sized(width: width, height: height, child: child),
    ),
  );

  final colorEndec = Endec.u32.xmap(Color.new, (other) => other.argb);

  registerWidgetEndec<Panel>(
    'panel',
    (builder) => builder.with4Fields(
      colorEndec.fieldOf('@argument', (struct) => struct.color),
      Endec.f32
          .xmap((self) => CornerRadius.all(self), (_) => throw UnimplementedError())
          .fieldOf('corner_radius', (struct) => struct.cornerRadius, defaultValueFactory: () => const CornerRadius()),
      Endec.f32.optionalOf().fieldOf(
        'outline_thickness',
        (struct) => struct.outlineThickness,
        defaultValueFactory: () => null,
      ),
      widgetEndec.optionalOf().fieldOf('@child', (struct) => struct.child, defaultValueFactory: () => null),
      (color, cornerRadius, outlineThickness, child) =>
          Panel(color: color, cornerRadius: cornerRadius, outlineThickness: outlineThickness, child: child),
    ),
  );

  registerWidgetEndec<Text>(
    'text',
    (builder) => builder.with1Field(Endec.string.fieldOf('@argument', (struct) => struct.text), (text) => Text(text)),
  );

  registerWidgetEndec<RawImage>(
    'image',
    (builder) => builder.with3Fields(
      Endec.string
          .xmap(Uri.parse, (other) => throw UnimplementedError())
          .fieldOf('@argument', (struct) => throw UnimplementedError()),
      Endec.string
          .xmap(
            (self) => switch (self) {
              'linear' => ImageFilter.linear,
              'nearest' => ImageFilter.nearest,
              _ => throw ArgumentError(),
            },
            (_) => throw UnimplementedError(),
          )
          .optionalOf()
          .fieldOf('filter', (struct) => struct.filter, defaultValueFactory: () => null),
      Endec.string
          .xmap(
            (self) => switch (self) {
              'none' => ImageWrap.none,
              'stretch' => ImageWrap.stretch,
              'clamp' => ImageWrap.clamp,
              'repeat' => ImageWrap.repeat,
              'mirrored_repeat' => ImageWrap.mirroredRepeat,
              _ => throw ArgumentError(),
            },
            (_) => throw UnimplementedError(),
          )
          .optionalOf()
          .fieldOf('wrap', (struct) => struct.wrap, defaultValueFactory: () => null),
      (uri, filter, wrap) {
        final provider = uri.scheme != 'file' ? NetworkImageProvider(uri) : FileImageProvider(File(uri.path));
        return RawImage(provider: provider, filter: filter ?? .nearest, wrap: wrap ?? .stretch);
      },
    ),
  );

  registerWidgetEndec<Flex>(
    'flex',
    (builder) => builder.with4Fields(
      Endec.string
          .xmap(
            (self) => switch (self) {
              'column' => LayoutAxis.vertical,
              'row' => LayoutAxis.horizontal,
              _ => throw ArgumentError(),
            },
            (other) => throw UnimplementedError(),
          )
          .fieldOf('@argument', (struct) => struct.mainAxis),
      Endec.string
          .xmap(
            (self) => switch (self) {
              'start' => MainAxisAlignment.start,
              'end' => MainAxisAlignment.end,
              'center' => MainAxisAlignment.center,
              'space_between' => MainAxisAlignment.spaceBetween,
              'space_around' => MainAxisAlignment.spaceAround,
              'space_evenly' => MainAxisAlignment.spaceEvenly,
              _ => throw ArgumentError(),
            },
            (_) => throw UnimplementedError(),
          )
          .optionalOf()
          .fieldOf('main_axis_alignment', (struct) => struct.mainAxisAlignment, defaultValueFactory: () => null),
      Endec.string
          .xmap(
            (self) => switch (self) {
              'start' => CrossAxisAlignment.start,
              'end' => CrossAxisAlignment.end,
              'center' => CrossAxisAlignment.center,
              'stretch' => CrossAxisAlignment.stretch,
              'baseline' => CrossAxisAlignment.baseline,
              _ => throw ArgumentError(),
            },
            (_) => throw UnimplementedError(),
          )
          .optionalOf()
          .fieldOf('cross_axis_alignment', (struct) => struct.crossAxisAlignment, defaultValueFactory: () => null),
      widgetEndec.listOf().fieldOf('@children', (struct) => struct.children),
      (mainAxis, mainAxisAlignment, crossAxisAlignment, children) => Flex(
        mainAxis: mainAxis,
        mainAxisAlignment: mainAxisAlignment ?? .start,
        crossAxisAlignment: crossAxisAlignment ?? .start,
        children: children,
      ),
    ),
  );

  registerWidgetEndec<Flexible>(
    'flexible',
    (builder) => builder.with2Fields(
      Endec.f32.optionalOf().fieldOf('flex_factor', (struct) => struct.flexFactor, defaultValueFactory: () => null),
      widgetEndec.fieldOf('@child', (struct) => struct.child),
      (flexFactor, child) => Flexible(flexFactor: flexFactor ?? 1.0, child: child),
    ),
  );

  registerWidgetEndec<Stack>(
    'stack',
    (builder) => builder.with2Fields(
      alignmentEndec.optionalOf().fieldOf('alignment', (struct) => struct.alignment, defaultValueFactory: () => null),
      widgetEndec.listOf().fieldOf('@children', (struct) => struct.children),
      (alignment, children) => Stack(alignment: alignment ?? Alignment.topLeft, children: children),
    ),
  );

  registerWidgetEndec<StackBase>(
    'stack_base',
    (builder) =>
        builder.with1Field(widgetEndec.fieldOf('@child', (struct) => struct.child), (child) => StackBase(child: child)),
  );

  registerWidgetEndec<Button>(
    'button',
    (builder) => builder.with3Fields(
      Endec.of(
        (_, _, _) => throw UnimplementedError(),
        (ctx, deserializer) => ctx.getAttributeValue(handlersAttribute)[Endec.string.decode(ctx, deserializer)],
      ).fieldOf('handler', (struct) => struct.onClick),
      jsonEndec.listOf().fieldOf('@arguments', (struct) => throw UnimplementedError()),
      widgetEndec.fieldOf('@child', (struct) => struct.child),
      (handler, arguments, child) => Button(
        onClick: () {
          if (handler == null) return;
          Function.apply(handler, arguments);
        },
        child: child,
      ),
    ),
  );

  Logger.root.level = Level.FINE;
  Logger.root.onRecord.listen((event) {
    print('[${event.loggerName}] (${event.level.toString().toLowerCase()}) ${event.message}');
  });

  final (app, _) = await createBraidAppWithWindow(
    name: 'kdl',
    baseLogger: Logger('kdl_app'),
    resources: BraidResources.filesystem(fontDirectory: 'resources/font', shaderDirectory: 'resources/shader'),
    defaultFontFamily: 'NotoSans',
    width: 400,
    height: 400,
    widget: const KdlApp(),
  );

  runBraidApp(app: app, reloadHook: true);
}

class KdlApp extends StatelessWidget {
  const KdlApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BraidTheme(
      child: Panel(
        color: BraidTheme.defaultBackgroundColor,
        child: KdlWidgetLoader(handlers: {'a_handler': (arg) => print('button: $arg')}),
      ),
    );
  }
}

class KdlWidgetLoader extends StatefulWidget {
  final Map<String, Function> handlers;
  const KdlWidgetLoader({super.key, required this.handlers});

  @override
  WidgetState<KdlWidgetLoader> createState() => _KdlWidgetLoaderState();
}

class _KdlWidgetLoaderState extends WidgetState<KdlWidgetLoader> {
  final Logger logger = Logger('kdl_app.loader');
  final File file = File('test/experiments.kdl');
  late final StreamSubscription fileWatch;

  Widget? kdlWidget;

  @override
  void init() {
    fileWatch = file.watch(events: FileSystemEvent.modify).listen((event) => _reload());
    _reload();
  }

  @override
  void dispose() {
    fileWatch.cancel();
  }

  void _reload() async {
    final content = await file.readAsString();
    try {
      final document = KdlDocument.parse(content);
      final widget = fromKdl(
        widgetEndec,
        document.first,
        ctx: SerializationContext(attributes: [handlersAttribute.instance(this.widget.handlers)]),
      );
      setState(() {
        kdlWidget = widget;
      });
    } catch (err) {
      logger.warning('failed to reload widget from file: $err');
      setState(() {
        kdlWidget = Center(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text('failed to reload widget from file:', style: TextStyle(bold: true)),
              Text(err.toString(), style: TextStyle(color: BraidTheme.of(context).elementColor)),
            ],
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ?kdlWidget,
        Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            insets: const Insets.all(20),
            child: Button(
              onClick: () => _reload(),
              child: const Icon(icon: Icons.refresh),
            ),
          ),
        ),
      ],
    );
  }
}
