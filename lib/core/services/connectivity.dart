export 'connectivity_stub.dart'
    if (dart.library.html) 'connectivity_web.dart'
    if (dart.library.io) 'connectivity_mobile.dart';
