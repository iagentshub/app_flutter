import '../models/local_knowledge_file.dart';
import 'directory_picker_io.dart'
    if (dart.library.js_interop) 'directory_picker_web.dart'
    as implementation;

Future<KnowledgeDirectorySelection?> pickKnowledgeDirectory({
  KnowledgeDirectoryProgressCallback? onProgress,
}) => implementation.pickKnowledgeDirectory(onProgress: onProgress);
