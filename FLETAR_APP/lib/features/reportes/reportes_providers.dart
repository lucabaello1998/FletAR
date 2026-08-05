import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import 'data/reportes_api.dart';

final reportesApiProvider = Provider((ref) => ReportesApi(ref.watch(dioProvider)));
