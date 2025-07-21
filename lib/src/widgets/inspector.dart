import 'dart:async';
import 'dart:developer';
import 'dart:isolate';
import 'dart:math';

import 'package:diamond_gl/diamond_gl.dart' as dgl;
import 'package:diamond_gl/glfw.dart';
import 'package:meta/meta.dart';
import 'package:vector_math/vector_math.dart';
import 'package:vm_service/vm_service.dart' as vms;
import 'package:vm_service/vm_service_io.dart' as vms;

import '../animation/easings.dart';
import '../baked_assets.g.dart';
import '../core/app.dart';
import '../core/constraints.dart';
import '../core/cursors.dart';
import '../core/math.dart';
import '../framework/instance.dart';
import '../framework/proxy.dart';
import '../framework/widget.dart';
import '../resources.dart';
import '../text/text_layout.dart';
import 'animated_widgets.dart';
import 'basic.dart';
import 'button.dart';
import 'collapsible.dart';
import 'container.dart';
import 'drag_arena.dart';
import 'flex.dart';
import 'grid.dart';
import 'icon.dart';
import 'layout_builder.dart';
import 'scroll.dart';
import 'shared_state.dart';
import 'slider.dart';
import 'stack.dart';
import 'text.dart';
import 'text_input.dart';
import 'theme.dart';

class InstancePicker extends StatefulWidget {
  final Stream<()> activateEvents;
  final void Function(WidgetInstance pickedInstance) pickCallback;
  final Widget child;

  const InstancePicker({super.key, required this.activateEvents, required this.pickCallback, required this.child});

  @override
  WidgetState<InstancePicker> createState() => _InstancePickerState();
}

class _InstancePickerState extends WidgetState<InstancePicker> with StreamListenerState {
  BuildContext? childContext;
  WidgetInstance? pickedInstance;

  bool picking = false;

  @override
  void init() {
    streamListen((widget) => widget.activateEvents, (event) {
      setState(() {
        picking = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        StackBase(
          child: Builder(
            builder: (context) {
              childContext = context;
              return widget.child;
            },
          ),
        ),
        if (picking)
          MouseArea(
            moveCallback: (toX, toY) {
              final hitTest = HitTestState();
              childContext!.instance!.hitTest(toX, toY, hitTest);

              pickedInstance?.debugHighlighted = false;

              pickedInstance = hitTest
                  .firstWhere((hit) => hit.instance.widget is! Align && hit.instance.widget is! DragArena)
                  ?.instance;
              pickedInstance?.debugHighlighted = true;
            },
            clickCallback: (x, y, button) {
              if (button == glfwMouseButtonLeft) {
                if (pickedInstance != null) {
                  pickedInstance!.debugHighlighted = false;
                  widget.pickCallback(pickedInstance!);
                }

                setState(() {
                  picking = false;
                });
              }

              return true;
            },
            child: const Padding(insets: Insets()),
          ),
      ],
    );
  }
}

// ---

@immutable
class RevealInstanceEvent {
  final WidgetInstance instance;
  final Set<WidgetInstance> fullPath;

  RevealInstanceEvent(this.instance) : fullPath = instance.ancestors.followedBy([instance]).toSet();
}

class BraidInspector {
  WidgetProxy? rootProxy;
  WidgetInstance? rootInstance;

  final StreamController<()> _refreshEvents = StreamController.broadcast(sync: true);
  final StreamController<()> _pickEvents = StreamController.broadcast(sync: true);
  final StreamController<RevealInstanceEvent> _revealEvents = StreamController.broadcast(sync: true);
  bool _active = false;
  AppState? currentApp;
  dgl.Window? currentWindow;

  Stream<()> get onPick => _pickEvents.stream;

  void activate() async {
    if (rootProxy == null || rootInstance == null) {
      throw StateError('cannot activate the braid inspector before the root proxy and instance have been set');
    }

    if (currentApp != null) {
      dgl.glfw.showWindow(currentWindow!.handle);
      return;
    }

    if (_active) return;
    _active = true;

    final (newApp, newWindow) = await createBraidAppWithWindow(
      name: 'braid inspector',
      enableInspector: false,
      width: 800,
      height: 500,
      // TODO: consider baking these fonts
      resources: BakedAssetResources(fontDelegate: BraidResources.fonts('resources/font')),
      defaultFontFamily: 'NotoSans',
      widget: InspectorWidget(rootProxy: rootProxy!, rootInstance: rootInstance!, inspector: this),
    );

    currentApp = newApp;
    currentWindow = newWindow;

    await runBraidApp(app: newApp, reloadHook: true);

    currentApp = null;
    currentWindow = null;
    _active = false;
  }

  void revealInstance(WidgetInstance instance) {
    if (!_active) return;
    _revealEvents.add(RevealInstanceEvent(instance));
  }

  void refresh() {
    _refreshEvents.add(const ());
  }

  void close() {
    currentApp?.scheduleShutdown();

    currentApp = null;
    currentWindow = null;
    _active = false;
  }
}

class InspectorWidget extends StatefulWidget {
  final WidgetProxy rootProxy;
  final WidgetInstance rootInstance;
  final BraidInspector inspector;

  InspectorWidget({super.key, required this.rootProxy, required this.rootInstance, required this.inspector});

  @override
  WidgetState<InspectorWidget> createState() => _InspectorWidgetState();
}

class _InspectorWidgetState extends WidgetState<InspectorWidget> with StreamListenerState {
  vms.VmService? vmService;
  InspectorState? inspectorState;

  @override
  void init() {
    _setupVmService();

    streamListen((widget) => widget.inspector._refreshEvents.stream, (_) => setState(() {}));
    streamListen(
      (widget) => widget.inspector._revealEvents.stream,
      (event) => inspectorState?.setState(() {
        inspectorState!.evalContext = event.instance;
        inspectorState!.lastRevealEvent = event;
      }),
    );
  }

  Future<void> _setupVmService() async {
    final serviceUri = (await Service.getInfo()).serverWebSocketUri;
    if (serviceUri == null) return;

    final service = await vms.vmServiceConnectUri(serviceUri.toString());
    vmService = service;

    inspectorState!.vmService = vmService;
  }

  @override
  void dispose() {
    vmService?.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BraidTheme(
      backgroundColor: const dgl.Color.rgb(0x111319),
      elevatedColor: const dgl.Color.rgb(0x1d2026),
      elementColor: const dgl.Color.rgb(0xabb0bf),
      disabledColor: const dgl.Color.rgb(0x1d2026),
      accentColor: const dgl.Color.rgb(0xa6c3ff),
      textStyle: const TextStyle(color: dgl.Color.rgb(0xebf0ff)),
      buttonStyle: const ButtonStyle(textStyle: TextStyle(color: dgl.Color.rgb(0x000b21))),
      child: SharedState(
        initState: InspectorState.new,
        child: Builder(
          builder: (context) {
            inspectorState = SharedState.get<InspectorState>(context, withDependency: false);

            return Panel(
              color: BraidTheme.of(context).backgroundColor,
              child: Column(
                children: [
                  Flexible(
                    child: Row(
                      children: [
                        Flexible(
                          child: Stack(
                            children: [
                              InspectorScrollView(
                                child: InstanceTreeView(
                                  revealEvents: widget.inspector._revealEvents.stream,
                                  viewInstance: widget.rootInstance,
                                ),
                              ),
                              Align(
                                alignment: Alignment.bottomRight,
                                child: InspectorActionButtons(inspector: widget.inspector),
                              ),
                            ],
                          ),
                        ),
                        InstanceDetails(),
                      ],
                    ),
                  ),
                  EvalBox(evalContext: widget.rootInstance),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class InspectorActionButtons extends StatelessWidget {
  final BraidInspector inspector;
  const InspectorActionButtons({super.key, required this.inspector});

  @override
  Widget build(BuildContext context) {
    return Padding(
      insets: const Insets.all(10),
      child: Row(
        separator: const Padding(insets: Insets.axis(horizontal: 5)),
        children: [
          Button(
            style: _buttonStyle,
            onClick: () {
              final isolate = Service.getIsolateId(Isolate.current);
              SharedState.get<InspectorState>(context, withDependency: false).vmService!.reloadSources(isolate!);
            },
            child: Icon(icon: Icons.mode_heat),
          ),
          Button(
            style: _buttonStyle,
            onClick: () {
              inspector._pickEvents.add(const ());
            },
            child: Icon(icon: Icons.colorize),
          ),
        ],
      ),
    );
  }

  static const _buttonStyle = ButtonStyle(padding: Insets.all(5), cornerRadius: CornerRadius.all(10));
}

class EvalBox extends StatefulWidget {
  final Object evalContext;
  const EvalBox({super.key, required this.evalContext});

  @override
  WidgetState<EvalBox> createState() => _EvalBoxState();
}

class _EvalBoxState extends WidgetState<EvalBox> {
  bool open = true;

  TextEditingController evalController = TextEditingController();
  String? evalResult;
  bool error = false;

  @override
  Widget build(BuildContext context) {
    final evalContext = SharedState.select<InspectorState, Object?>(context, (state) => state.evalContext);

    return Column(
      children: [
        Padding(
          insets: const Insets(top: -5),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Padding(
                insets: const Insets.axis(vertical: 5),
                child: Sized(height: 1, child: Panel(color: BraidTheme.of(context).elementColor)),
              ),
              Center(
                child: Button(
                  style: const ButtonStyle(
                    cornerRadius: CornerRadius.all(6),
                    padding: Insets.axis(vertical: -2, horizontal: 4),
                  ),
                  onClick: () => setState(() {
                    open = !open;
                  }),
                  child: Icon(icon: open ? Icons.arrow_drop_down : Icons.arrow_drop_up, size: 16),
                ),
              ),
            ],
          ),
        ),
        Visibility(
          visible: open,
          child: Padding(
            insets: const Insets.axis(horizontal: 5),
            child: Column(
              children: [
                Text('eval on: $evalContext'),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Padding(
                      insets: const Insets(right: 5),
                      child: Icon(icon: Icons.terminal, size: 20),
                    ),
                    Flexible(
                      child: KeyboardInput(
                        keyDownCallback: evalContext != null
                            ? (keyCode, modifiers) {
                                if (keyCode != glfwKeyEnter) return false;

                                eval(
                                  SharedState.get<InspectorState>(context, withDependency: false).vmService!,
                                  evalContext,
                                );
                                return true;
                              }
                            : null,
                        child: SynkTextField(controller: evalController),
                      ),
                    ),
                  ],
                ),
                evalResult != null ? Text(evalResult!, style: error ? _errorStyle : null) : const Text('...'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void eval(vms.VmService vmService, Object context) async {
    final isolate = Service.getIsolateId(Isolate.current);
    final targetId = Service.getObjectId(context);

    try {
      final result = vms.InstanceRef.parse((await vmService.evaluate(isolate!, targetId!, evalController.text)).json);

      final resultAsString = vms.InstanceRef.parse(
        (await vmService.invoke(isolate, result!.id!, 'toString', const [])).json,
      )!.valueAsString;

      setState(() {
        evalResult = resultAsString;
        error = false;
      });
    } on vms.RPCError catch (e) {
      setState(() {
        evalResult = e.details;
        error = true;
      });
    }
  }

  static const _errorStyle = TextStyle(color: dgl.Color.red);
}

// ---

class InstanceDetails extends StatelessWidget {
  const InstanceDetails({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = BraidTheme.of(context);
    final instance = SharedState.select<InspectorState, Object?>(context, (state) => state.evalContext);

    Widget child;
    if (instance is WidgetInstance) {
      final instanceTransform = instance.computeTransformFrom(ancestor: null)..invert();
      final (absX, absY) = instanceTransform.transform2(instance.transform.x, instance.transform.y);

      child = Grid(
        mainAxis: LayoutAxis.vertical,
        crossAxisCells: 2,
        cellFit: const CellFit.tight(),
        children: _colorRows(
          alternateColor: theme.elevatedColor,
          crossAxisCells: 2,
          cells: [
            Text('Rel. Position', style: const TextStyle(bold: true)),
            Text('${instance.transform.x.toStringAsFixed(1)}, ${instance.transform.y.toStringAsFixed(1)}'),
            Text('Abs. Position', style: const TextStyle(bold: true)),
            Text('${absX.toStringAsFixed(1)}, ${absY.toStringAsFixed(1)}'),
            Text('Width', style: const TextStyle(bold: true)),
            Text('${instance.transform.width.toStringAsFixed(1)}px'),
            Text('Height', style: const TextStyle(bold: true)),
            Text('${instance.transform.height.toStringAsFixed(1)}px'),
            Text('Widget', style: const TextStyle(bold: true)),
            Text(instance.widget.runtimeType.toString()),
          ],
        ),
      );
    } else {
      child = Flexible(child: Center(child: Text('no instance selected')));
    }

    return Row(
      children: [
        Sized(width: 1, child: Panel(color: theme.elementColor)),
        Sized(
          width: 250,
          child: Column(
            children: [
              const Padding(insets: Insets(bottom: 5), child: Text('Selected Instance Details')),
              child,
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _colorRows({
    required dgl.Color alternateColor,
    required int crossAxisCells,
    required List<Widget> cells,
  }) {
    final result = <Widget>[];

    var rowIdx = 0;
    var crossAxisIdx = 0;
    for (final widget in cells) {
      if (rowIdx % 2 == 0) {
        result.add(widget);
      } else {
        result.add(Panel(color: alternateColor, child: widget));
      }

      if (++crossAxisIdx == crossAxisCells) {
        crossAxisIdx = 0;
        rowIdx++;
      }
    }

    return result;
  }
}

// ---

class InspectorState extends ShareableState {
  vms.VmService? vmService;

  Object? evalContext;
  RevealInstanceEvent? lastRevealEvent;
}

class InstanceTreeView extends StatefulWidget {
  final Stream<RevealInstanceEvent> revealEvents;
  final WidgetInstance viewInstance;

  const InstanceTreeView({super.key, required this.revealEvents, required this.viewInstance});

  @override
  WidgetState<InstanceTreeView> createState() => _InstanceTreeViewState();
}

class _InstanceTreeViewState extends WidgetState<InstanceTreeView> with StreamListenerState {
  var builtOnce = false;
  var highlight = false;

  void _reveal() => schedulePostLayoutCallback(() => Scrollable.reveal(context));

  @override
  void init() {
    streamSubscribe(
      (widget) => widget.revealEvents,
      (stream) => stream.where((event) => event.instance == widget.viewInstance).listen((_) => _reveal()),
    );
  }

  @override
  void didUpdateWidget(InstanceTreeView oldWidget) {
    if (oldWidget.viewInstance != widget.viewInstance) {
      setState(() {
        highlight = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = InstanceTitle(instance: widget.viewInstance);

    final children = <WidgetInstance>[];
    widget.viewInstance.visitChildren(children.add);

    if (highlight) {
      schedulePostLayoutCallback(() => setState(() => highlight = false));
    }

    bool startCollapsed = true;
    if (!builtOnce) {
      builtOnce = true;

      final lastRevealEvent = SharedState.select<InspectorState, RevealInstanceEvent?>(
        context,
        (state) => state.lastRevealEvent,
      );

      if (lastRevealEvent?.instance == widget.viewInstance) {
        _reveal();
      }

      startCollapsed = !(lastRevealEvent?.fullPath.contains(widget.viewInstance) ?? false);
    }

    return AnimatedPanel(
      duration: highlight ? Duration.zero : const Duration(milliseconds: 1250),
      easing: Easing.outSine,
      color: highlight ? dgl.Color.ofHsv((widget.viewInstance.depth % 15) / 15, .75, 1, .5) : const dgl.Color(0),
      cornerRadius: const CornerRadius.all(2),
      outlineThickness: 1,
      child: children.isNotEmpty
          ? CollapsibleEntry(
              onExpand: widget.revealEvents
                  .where((event) => event.fullPath.contains(widget.viewInstance))
                  .map((_) => const ()),
              startCollapsed: startCollapsed,
              title: title,
              content: Column(
                children: children
                    .map((child) => InstanceTreeView(revealEvents: widget.revealEvents, viewInstance: child))
                    .toList(),
              ),
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(icon: Icons.fiber_manual_record, size: 18),
                title,
              ],
            ),
    );
  }
}

class CollapsibleEntry extends StatefulWidget {
  final Stream<()>? onExpand;
  final bool startCollapsed;
  final Widget title;
  final Widget content;

  const CollapsibleEntry({
    super.key,
    this.onExpand,
    this.startCollapsed = true,
    required this.title,
    required this.content,
  });

  @override
  WidgetState<CollapsibleEntry> createState() => _CollapsibleEntryState();
}

class _SubscriptionData<W, T> {
  final Stream<T>? Function(W widget) getter;
  final StreamSubscription<T> Function(Stream<T> event) listenerFactory;

  Stream<T>? currentStream;
  StreamSubscription<T>? currentSubscription;

  _SubscriptionData(W widget, this.getter, this.listenerFactory) {
    _listenOn(widget);
  }

  void _listenOn(W widget) {
    currentStream = getter(widget);
    if (currentStream == null) return;

    currentSubscription = listenerFactory(currentStream!);
  }

  void update(W newWidget) {
    final newStream = getter(newWidget);
    if (newStream == currentStream) return;

    currentSubscription?.cancel();
    _listenOn(newWidget);
  }
}

mixin StreamListenerState<T extends StatefulWidget> on WidgetState<T> {
  final List<_SubscriptionData<T, dynamic>> _streamSubscriptions = [];

  @protected
  void streamListen<S>(Stream<S>? Function(T widget) streamGetter, void Function(S event) onData) {
    _streamSubscriptions.add(
      _SubscriptionData(widget, streamGetter, (event) => event.listen((event) => onData(event as S))),
    );
  }

  @protected
  void streamSubscribe<S>(
    Stream<S>? Function(T widget) streamGetter,
    StreamSubscription<S> Function(Stream<S> stream) listenerFactory,
  ) {
    _streamSubscriptions.add(_SubscriptionData(widget, streamGetter, (event) => listenerFactory(event as Stream<S>)));
  }

  @override
  void didUpdateWidget(T oldWidget) {
    super.didUpdateWidget(oldWidget);

    for (final subscription in _streamSubscriptions) {
      subscription.update(widget);
    }
  }

  @override
  void dispose() {
    super.dispose();

    for (final subscription in _streamSubscriptions) {
      subscription.currentSubscription?.cancel();
    }
  }
}

class _CollapsibleEntryState extends WidgetState<CollapsibleEntry> with StreamListenerState {
  late bool collapsed;

  void _expand(_) {
    setState(() {
      collapsed = false;
    });
  }

  @override
  void init() {
    streamListen((widget) => widget.onExpand, _expand);
    collapsed = widget.startCollapsed;
  }

  @override
  Widget build(BuildContext context) {
    return Actions(
      actions: {
        _expandTrigger: () => setState(() => collapsed = false),
        _collapseTrigger: () => setState(() => collapsed = true),
      },
      child: LazyCollapsible(
        collapsed: collapsed,
        onToggled: (nowCollapsed) => setState(() => collapsed = nowCollapsed),
        title: widget.title,
        content: widget.content,
      ),
    );
  }

  static final _expandTrigger = [
    ActionTrigger(mouseButtons: {}, keyCodes: {glfwKeyRight}),
  ];
  static final _collapseTrigger = [
    ActionTrigger(mouseButtons: {}, keyCodes: {glfwKeyLeft}),
  ];
}

class InstanceTitle extends StatefulWidget {
  final WidgetInstance instance;
  const InstanceTitle({super.key, required this.instance});

  @override
  WidgetState<InstanceTitle> createState() => _InstanceTitleState();
}

class _InstanceTitleState extends WidgetState<InstanceTitle> {
  bool hovered = false;

  @override
  Widget build(BuildContext context) {
    final selected =
        SharedState.select<InspectorState, Object?>(context, (state) => state.evalContext) == widget.instance;

    final title = Panel(
      color: selected ? dgl.Color.values(1, 1, 1, .25) : const dgl.Color(0),
      cornerRadius: const CornerRadius.all(5),
      child: Row(
        children: [
          Text(widget.instance.runtimeType.toString(), softWrap: false, style: TextStyle(bold: hovered)),
          if (widget.instance.isRelayoutBoundary)
            Padding(
              insets: const Insets(left: 5),
              child: Icon(icon: Icons.border_outer, size: 20, color: const dgl.Color.rgb(0x6DE1D2)),
            ),
        ],
      ),
    );

    return KeyboardInput(
      focusGainedCallback: () =>
          SharedState.set<InspectorState>(context, (state) => state.evalContext = widget.instance),
      child: MouseArea(
        enterCallback: () => setState(() {
          widget.instance.debugHighlighted = true;
          hovered = true;
        }),
        exitCallback: () => setState(() {
          widget.instance.debugHighlighted = false;
          hovered = false;
        }),
        cursorStyle: CursorStyle.crosshair,
        child: title,
      ),
    );
  }
}

// ---

class SynkTextField extends StatefulWidget {
  final TextEditingController controller;
  const SynkTextField({super.key, required this.controller});

  @override
  WidgetState<SynkTextField> createState() => _SynkTextFieldState();
}

class _SynkTextFieldState extends WidgetState<SynkTextField> {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: BraidTheme.of(context).elevatedColor,
      cornerRadius: const CornerRadius.all(5),
      padding: const Insets.all(4),
      child: Sized(
        height: 18,
        child: RawTextField(
          controller: widget.controller,
          textStyle: const SpanStyle(
            color: dgl.Color.white,
            fontSize: 13.0,
            fontFamily: 'monospace',
            bold: false,
            italic: false,
            underline: false,
          ),
          autoFocus: false,
          softWrap: false,
          allowMultipleLines: false,
        ),
      ),
    );
  }
}

class RawTextField extends StatefulWidget {
  final TextEditingController controller;
  final SpanStyle textStyle;
  final bool autoFocus;
  final bool softWrap;
  final bool allowMultipleLines;

  const RawTextField({
    super.key,
    required this.controller,
    required this.textStyle,
    required this.autoFocus,
    required this.softWrap,
    required this.allowMultipleLines,
  });

  @override
  WidgetState<RawTextField> createState() => _RawTextFieldState();
}

class _RawTextFieldState extends WidgetState<RawTextField> {
  Timer? blinkTimer;
  bool showCursor = false;

  final ScrollController horizontalController = ScrollController();
  final ScrollController verticalController = ScrollController();
  // TextInputInstance? _inputInstance;
  // WidgetInstance? _scrollInstance;

  BuildContext? inputContext;

  @override
  void init() {
    widget.controller.addListener(_listener);
  }

  @override
  void didUpdateWidget(RawTextField oldWidget) {
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller.removeListener(_listener);
      widget.controller.addListener(_listener);
    }
  }

  @override
  void dispose() {
    blinkTimer?.cancel();
    widget.controller.removeListener(_listener);
  }

  void _listener() {
    schedulePostLayoutCallback(() {
      final inputInstance = inputContext!.instance as TextInputInstance;
      final (x: cursorX, y: cursorY) = inputInstance.cursorPosition;
      final lineHeight = inputInstance.currentLine.height;

      Scrollable.revealAabb(
        inputContext!,
        Aabb3.minMax(Vector3(cursorX, cursorY - lineHeight, 0), Vector3(cursorX + 2, cursorY, 0)),
      );
    });

    _restartBlinking();
  }

  void _restartBlinking() {
    blinkTimer?.cancel();
    setState(() {
      showCursor = true;
    });

    blinkTimer = Timer.periodic(const Duration(milliseconds: 650), (_) {
      setState(() {
        showCursor = !showCursor;
      });
    });
  }

  void _stopBlinking() {
    blinkTimer?.cancel();
    setState(() {
      showCursor = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardInput(
      focusGainedCallback: () => _restartBlinking(),
      focusLostCallback: () => _stopBlinking(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Scrollable.both(
            horizontalController: horizontalController,
            verticalController: verticalController,
            child: Constrain(
              constraints: Constraints.only(minWidth: constraints.minWidth, minHeight: constraints.minHeight),
              child: Builder(
                builder: (context) {
                  inputContext = context;
                  // we skip the ListneableBuilder that would usually be required here
                  // since the entire text field rebuilds through a listener on the controller
                  // either way
                  return TextInput(
                    controller: widget.controller,
                    showCursor: showCursor,
                    softWrap: widget.softWrap,
                    autoFocus: widget.autoFocus,
                    allowMultipleLines: widget.allowMultipleLines,
                    style: widget.textStyle,
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---

class Scrollbar extends StatelessWidget {
  final LayoutAxis axis;
  final ScrollController controller;

  const Scrollbar({super.key, required this.axis, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final currentOffset = controller.offset;
            final maxOffset = controller.maxOffset;

            final selfSize = constraints.maxOnAxis(axis);
            final childSize = selfSize + maxOffset;
            final scrollbarLength = min((selfSize / childSize) * selfSize, selfSize);

            return Sized(
              height: axis.choose(6, null),
              width: axis.choose(null, 6),
              child: maxOffset != 0
                  ? RawSlider(
                      min: axis.choose(0, maxOffset),
                      max: axis.choose(maxOffset, 0),
                      step: null,
                      value: currentOffset,
                      axis: axis,
                      onUpdate: (offset) => controller.offset = offset,
                      style: DefaultSliderStyle.of(context).copy(handleSize: max(15, scrollbarLength)),
                      track: null,
                      handle: Panel(
                        color: BraidTheme.of(context).elementColor,
                        cornerRadius: const CornerRadius.all(3),
                      ),
                    )
                  : const Padding(insets: Insets()),
            );
          },
        );
      },
    );
  }
}

class InspectorScrollView extends StatefulWidget {
  final ScrollController? horizontalController;
  final ScrollController? verticalController;
  final Widget child;

  const InspectorScrollView({super.key, this.horizontalController, this.verticalController, required this.child});

  @override
  WidgetState<InspectorScrollView> createState() => _InspectorScrollViewState();
}

class _InspectorScrollViewState extends WidgetState<InspectorScrollView> {
  ScrollController? horizontalController;
  ScrollController? verticalController;

  void _updateControllers() {
    horizontalController = (widget.horizontalController ?? horizontalController) ?? ScrollController();
    verticalController = (widget.verticalController ?? verticalController) ?? ScrollController();
  }

  @override
  void init() {
    _updateControllers();
  }

  @override
  void didUpdateWidget(InspectorScrollView oldWidget) {
    _updateControllers();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Flexible(
          child: Row(
            children: [
              Flexible(
                child: Scrollable.both(
                  horizontalController: horizontalController,
                  verticalController: verticalController,
                  child: widget.child,
                ),
              ),
              Scrollbar(axis: LayoutAxis.vertical, controller: verticalController!),
            ],
          ),
        ),
        Scrollbar(axis: LayoutAxis.horizontal, controller: horizontalController!),
      ],
    );
  }
}
