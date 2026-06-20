import 'package:flutter/widgets.dart';

/// App-wide route observer so widgets can react to navigation (e.g. the
/// "continue reading" banner refreshes when the reader is popped). Registered in
/// [MaterialApp.navigatorObservers].
final RouteObserver<PageRoute<dynamic>> routeObserver =
    RouteObserver<PageRoute<dynamic>>();
