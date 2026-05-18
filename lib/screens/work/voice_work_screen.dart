import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/voice_parser_service.dart';

const _kGreen = Color(0xFF4CAF82);
const _kSurface = Color(0xFF1E1E1E);
const _kCard = Color(0xFF2A2A2A);

class VoiceWorkScreen extends StatefulWidget {
  const VoiceWorkScreen({super.key});

  @override
  State<VoiceWorkScreen> createState() => _VoiceWorkScreenState();
}

class _VoiceWorkScreenState extends State<VoiceWorkScreen>
    with SingleTickerProviderStateMixin {
  final _speech = SpeechToText();

  bool _speechAvailable = false;
  bool _isListening = false;
  String _recognizedText = '';
  VoiceCommand? _parsedCommand;
  bool _isSaving = false;

  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.22).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    if (!kIsWeb) _initSpeech();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    if (!kIsWeb) _speech.stop();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onError: (error) {
        if (mounted) _snack('음성 인식 오류: ${error.errorMsg}', error: true);
      },
      onStatus: (status) {
        // STT가 자동 종료될 때 UI 동기화
        if (!_speech.isListening && _isListening && mounted) {
          setState(() => _isListening = false);
          _pulseCtrl.stop();
          _pulseCtrl.reset();
        }
      },
    );
    if (mounted) setState(() {});
  }

  Future<void> _startListening() async {
    if (!_speechAvailable) {
      _snack('음성 인식을 사용할 수 없어요', error: true);
      return;
    }
    if (_speech.isListening) return;

    setState(() {
      _recognizedText = '';
      _parsedCommand = null;
      _isListening = true;
    });
    _pulseCtrl.repeat(reverse: true);

    await _speech.listen(
      onResult: (result) {
        setState(() => _recognizedText = result.recognizedWords);
        if (result.finalResult && result.recognizedWords.isNotEmpty) {
          _onFinalResult(result.recognizedWords);
        }
      },
      localeId: 'ko_KR',
      listenOptions: SpeechListenOptions(partialResults: true),
    );
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    _pulseCtrl.stop();
    _pulseCtrl.reset();
    setState(() => _isListening = false);
  }

  void _onFinalResult(String text) {
    _pulseCtrl.stop();
    _pulseCtrl.reset();
    final command = VoiceParserService.parse(text);
    setState(() {
      _isListening = false;
      _parsedCommand = command;
    });
  }

  Future<void> _confirm() async {
    final command = _parsedCommand;
    if (command == null) return;

    if (command.reptileName == null || command.reptileName!.isEmpty) {
      _snack('개체 이름을 인식하지 못했어요', error: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser!.id;

      // 개체 이름으로 ilike 검색
      final results = await client
          .from('reptiles')
          .select('id, name')
          .eq('user_id', userId)
          .ilike('name', '%${command.reptileName}%')
          .or('status.eq.active,status.eq.holdback');

      final reptiles = (results as List).cast<Map<String, dynamic>>();

      if (reptiles.isEmpty) {
        _snack('\'${command.reptileName}\' 개체를 찾지 못했어요', error: true);
        return;
      }

      Map<String, dynamic> reptile;
      if (reptiles.length == 1) {
        reptile = reptiles.first;
      } else {
        final picked = await _showReptileSelector(reptiles);
        if (picked == null || !mounted) return;
        reptile = picked;
      }

      final reptileId = reptile['id'] as String;
      final reptileName = reptile['name'] as String;

      if (command.type == VoiceCommandType.feeding) {
        await client.from('feeding_logs').insert({
          'reptile_id': reptileId,
          'fed_at': DateTime.now().toIso8601String(),
          'status': command.status?.value ?? 'fed',
          if (command.memo != null && command.memo!.isNotEmpty)
            'memo': command.memo,
        });
        if (mounted) {
          _snack('$reptileName ${command.status?.label ?? '급여완료'} 기록 완료!');
          setState(() {
            _recognizedText = '';
            _parsedCommand = null;
          });
        }
      } else if (command.type == VoiceCommandType.weight &&
          command.weightValue != null) {
        await client
            .from('reptiles')
            .update({'weight_g': command.weightValue})
            .eq('id', reptileId);
        if (mounted) {
          _snack('$reptileName 체중 ${command.weightValue}g 기록 완료!');
          setState(() {
            _recognizedText = '';
            _parsedCommand = null;
          });
        }
      }
    } on PostgrestException catch (e) {
      _snack('저장 실패: ${e.message}', error: true);
    } catch (_) {
      _snack('저장 중 오류가 발생했어요', error: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<Map<String, dynamic>?> _showReptileSelector(
      List<Map<String, dynamic>> reptiles) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: _kCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text(
              '어떤 개체인가요?',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
          ),
          ...reptiles.map(
            (r) => ListTile(
              title:
                  Text(r['name'] as String, style: const TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(ctx, r),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.redAccent : _kGreen,
    ));
  }

  String _commandSummary(VoiceCommand command) {
    final name = command.reptileName ?? '(개체명 없음)';
    return switch (command.type) {
      VoiceCommandType.feeding =>
        '$name — ${command.status?.label ?? '급여완료'}로 기록할까요?',
      VoiceCommandType.weight when command.weightValue != null =>
        '$name — ${command.weightValue}g로 체중 기록할까요?',
      VoiceCommandType.weight => '$name — 체중 숫자를 인식하지 못했어요',
      VoiceCommandType.memo =>
        '$name — 메모를 기록할까요?',
      VoiceCommandType.unknown =>
        '인식하지 못했어요. 다시 말씀해주세요.',
    };
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Scaffold(
        backgroundColor: const Color(0xFF121212),
        appBar: AppBar(
          backgroundColor: _kSurface,
          elevation: 0,
          title: const Text('음성 작업 모드',
              style: TextStyle(color: Colors.white)),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: const Center(
          child: Text(
            '음성 작업은 모바일 앱에서만 사용 가능해요',
            style: TextStyle(color: Colors.grey, fontSize: 15),
          ),
        ),
      );
    }

    final command = _parsedCommand;
    final isUnknown = command?.type == VoiceCommandType.unknown;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: _kSurface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('음성 작업 모드',
            style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          // ── 중앙 마이크 영역 ─────────────────────────────────────────────
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 인식된 텍스트
                  SizedBox(
                    height: 64,
                    child: Center(
                      child: Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          _isListening
                              ? (_recognizedText.isEmpty
                                  ? '듣는 중...'
                                  : _recognizedText)
                              : (_recognizedText.isEmpty
                                  ? '마이크 버튼을 눌러 말씀하세요'
                                  : _recognizedText),
                          style: TextStyle(
                            color: _isListening
                                ? Colors.white
                                : const Color(0xFF888888),
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 44),

                  // 마이크 버튼
                  GestureDetector(
                    onTap: _isListening ? _stopListening : _startListening,
                    child: _isListening
                        ? ScaleTransition(
                            scale: _pulseAnim,
                            child: const _MicButton(listening: true),
                          )
                        : const _MicButton(listening: false),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    _isListening ? '탭하여 중지' : '탭하여 시작',
                    style: const TextStyle(
                        color: Color(0xFF555555), fontSize: 12),
                  ),
                ],
              ),
            ),
          ),

          // ── 파싱 결과 카드 ────────────────────────────────────────────────
          if (command != null)
            _ResultCard(
              summary: _commandSummary(command),
              isUnknown: isUnknown,
              isSaving: _isSaving,
              canConfirm: !isUnknown &&
                  !(command.type == VoiceCommandType.weight &&
                      command.weightValue == null),
              onConfirm: _confirm,
              onRetry: () {
                setState(() {
                  _recognizedText = '';
                  _parsedCommand = null;
                });
                _startListening();
              },
              onCancel: () => setState(() {
                _recognizedText = '';
                _parsedCommand = null;
              }),
            ),
        ],
      ),
    );
  }
}

// ── 마이크 버튼 ────────────────────────────────────────────────────────────────

class _MicButton extends StatelessWidget {
  final bool listening;
  const _MicButton({required this.listening});

  @override
  Widget build(BuildContext context) {
    final color = listening ? Colors.redAccent : _kGreen;
    return Container(
      width: 104,
      height: 104,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: listening ? 0.5 : 0.35),
            blurRadius: 24,
            spreadRadius: 4,
          ),
        ],
      ),
      child: const Icon(Icons.mic, color: Colors.white, size: 44),
    );
  }
}

// ── 파싱 결과 카드 ─────────────────────────────────────────────────────────────

class _ResultCard extends StatelessWidget {
  final String summary;
  final bool isUnknown;
  final bool isSaving;
  final bool canConfirm;
  final VoidCallback onConfirm;
  final VoidCallback onRetry;
  final VoidCallback onCancel;

  const _ResultCard({
    required this.summary,
    required this.isUnknown,
    required this.isSaving,
    required this.canConfirm,
    required this.onConfirm,
    required this.onRetry,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUnknown
              ? const Color(0xFF333333)
              : _kGreen.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isUnknown
                    ? Icons.help_outline
                    : Icons.check_circle_outline,
                color: isUnknown ? Colors.grey : _kGreen,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  summary,
                  style: TextStyle(
                    color: isUnknown ? Colors.grey : Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (canConfirm) ...[
                Expanded(
                  child: SizedBox(
                    height: 42,
                    child: ElevatedButton(
                      onPressed: isSaving ? null : onConfirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kGreen,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            _kGreen.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('확인',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: OutlinedButton(
                    onPressed: onRetry,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _kGreen,
                      side: const BorderSide(color: _kGreen),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('다시 듣기'),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: OutlinedButton(
                    onPressed: onCancel,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey,
                      side: const BorderSide(color: Color(0xFF444444)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('취소'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
