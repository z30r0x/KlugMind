import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

import 'llm_service.dart';

/// Runs the model fully on-device. Same prompt, JSON schema and repair
/// pass as [LlmService]; only [generate] differs.
class OnDeviceLlmService extends LlmService {
  OnDeviceLlmService({required this.modelUrl, this.modelType = 'qwen'});

  final String modelUrl;
  final String modelType;

  /// Must not exceed the model file's KV cache (ekv1280 -> 1280).
  static const int maxTokens = 1280;
  static const Duration generateTimeout = Duration(seconds: 120);

  InferenceModel? _model;
  Future<void>? _ready;

  // VERIFY these enum names against flutter_gemma 0.16.5.
  static ModelType _typeFor(String name) => switch (name) {
        'gemma' => ModelType.gemmaIt,
        'qwen' => ModelType.qwen,
        _ => ModelType.general,
      };

  /// Downloads the model once (cached by the plugin). [onProgress] is 0-100.
  /// Concurrent callers share one initialisation; failures can be retried.
  Future<void> ensureReady({void Function(int percent)? onProgress}) async {
    final f = _ready ??= _init(onProgress);
    try {
      await f;
    } catch (_) {
      _ready = null;
      rethrow;
    }
  }

  Future<void> _init(void Function(int percent)? onProgress) async {
    if (_model != null) return;
    if (!modelUrl.startsWith('https://')) {
      throw const FormatException(
        'MODEL_URL is missing or invalid in .env (must start with https://).',
      );
    }
    try {
      // Future.value works whether hasActiveModel is sync or async.
      final has = await Future.value(FlutterGemma.hasActiveModel());
      if (!has) {
        await FlutterGemma.installModel(modelType: _typeFor(modelType))
            .fromNetwork(modelUrl)
            .withProgress((p) => onProgress?.call(p))
            .install();
      }
      _model = await FlutterGemma.getActiveModel(maxTokens: maxTokens);
    } catch (e) {
      debugPrint('OnDeviceLlmService init failed: $e');
      throw HttpException(
        'On-device model unavailable (download failed or device too weak): $e',
      );
    }
  }

  @override
  Future<String> generate(String prompt) async {
    await ensureReady();
    final chat = await _model!.createChat(temperature: 0.2);
    try {
      await chat.addQueryChunk(Message.text(text: prompt, isUser: true));
      final reply =
          await chat.generateChatResponse().timeout(generateTimeout);
      return reply is TextResponse ? reply.token : reply.toString();
    } finally {
      await chat.close();
    }
  }

  Future<void> dispose() async {
    await _model?.close();
    _model = null;
    _ready = null;
  }
}