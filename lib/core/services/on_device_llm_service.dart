import 'package:flutter_gemma/flutter_gemma.dart';

import 'llm_service.dart';

/// Runs the model fully on-device. Same prompt, JSON schema and repair
/// pass as [LlmService]; only [generate] differs.
class OnDeviceLlmService extends LlmService {
  OnDeviceLlmService({required this.modelUrl});

  final String modelUrl;
  InferenceModel? _model;

  /// Downloads the model once (cached by the plugin). [onProgress] is 0-100.
  Future<void> ensureReady({void Function(int percent)? onProgress}) async {
    if (_model != null) return;
    try {
      if (!FlutterGemma.hasActiveModel()) {
        await FlutterGemma.installModel(modelType: ModelType.gemmaIt)
            .fromNetwork(modelUrl)
            .withProgress((p) => onProgress?.call(p))
            .install();
      }
      _model = await FlutterGemma.getActiveModel(maxTokens: 3072);
    } catch (e) {
      throw HttpException(
          'On-device model unavailable (download failed or device too weak): $e');
    }
  }

  @override
  Future<String> generate(String prompt) async {
    await ensureReady();
    final chat = await _model!.createChat(temperature: 0.2);
    try {
      await chat.addQueryChunk(Message.text(text: prompt, isUser: true));
      final reply = await chat.generateChatResponse();
      return reply is TextResponse ? reply.token : reply.toString();
    } finally {
      await chat.close();
    }
  }

  Future<void> dispose() async => _model?.close();
}