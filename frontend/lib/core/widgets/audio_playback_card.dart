import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../theme/app_tokens.dart';
import 'error_text.dart';

class PlaybackSource {
  const PlaybackSource(this.url, {this.expiresAt});
  final String url;
  final DateTime? expiresAt;
}

/// B/C 공용. 만료 URL은 onRefresh로 서버에서 다시 받는다.
/// 사용: AudioPlaybackCard(source: PlaybackSource(url, expiresAt: expiresAt),
///   label: '부모님 목소리 듣기', onRefresh: reloadAudioSource)
/// reloadAudioSource는 today/stories를 재조회해 새 PlaybackSource를 반환한다.
/// 재조회 중 화면의 source를 교체하지 않는다. source 교체는 현재 재생을 중단한다.
class AudioPlaybackCard extends StatefulWidget {
  const AudioPlaybackCard({
    super.key,
    required this.source,
    this.label = '음성 듣기',
    this.onRefresh,
    this.enabled = true,
    this.playerFactory,
  });
  final PlaybackSource source;
  final String label;

  /// 만료 30초 전 또는 재생 오류 후 재시도할 때 호출한다.
  final Future<PlaybackSource> Function()? onRefresh;
  final bool enabled;

  /// 테스트에서 네이티브 오디오 없이 검증한다. 생성한 플레이어는 카드가 dispose한다.
  @visibleForTesting
  final AudioPlayer Function()? playerFactory;

  @override
  State<AudioPlaybackCard> createState() => AudioPlaybackCardState();
}

class AudioPlaybackCardState extends State<AudioPlaybackCard>
    with WidgetsBindingObserver {
  late final AudioPlayer _player;
  late PlaybackSource _source;
  StreamSubscription<PlayerState>? _stateSubscription;
  StreamSubscription<PlayerException>? _errorSubscription;
  bool _loading = false;
  bool _loaded = false;
  String? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _player = widget.playerFactory?.call() ?? AudioPlayer();
    _source = widget.source;
    WidgetsBinding.instance.addObserver(this);
    _stateSubscription = _player.playerStateStream.listen((_) {
      if (mounted) setState(() {});
    });
    _errorSubscription = _player.errorStream.listen((_) => _showError());
  }

  @override
  void didUpdateWidget(AudioPlaybackCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source.url != widget.source.url ||
        oldWidget.source.expiresAt != widget.source.expiresAt) {
      _generation++;
      _source = widget.source;
      _loaded = false;
      _loading = false;
      _error = null;
      unawaited(pause());
    }
    if (!widget.enabled) unawaited(pause());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(pause());
  }

  Future<void> pause() async {
    _generation++;
    if (mounted) setState(() => _loading = false);
    try {
      await _player.pause();
    } catch (_) {
      /* 종료 중 중복 정지 허용 */
    }
  }

  void _showError() {
    if (!mounted) return;
    setState(() {
      _loading = false;
      _loaded = false;
      _error = '소리를 불러오지 못했어요. 다시 눌러 주세요.';
    });
  }

  Future<void> _toggle() async {
    if (!widget.enabled || _loading) return;
    final generation = ++_generation;
    if (_player.playing &&
        _player.processingState != ProcessingState.completed) {
      await pause();
      return;
    }
    setState(() {
      _loading = true;
    });
    try {
      final expired =
          _source.expiresAt?.isBefore(
            DateTime.now().add(const Duration(seconds: 30)),
          ) ??
          false;
      if (expired || _error != null) {
        if (widget.onRefresh != null) {
          final refreshed = await widget.onRefresh!().timeout(
            const Duration(seconds: 20),
          );
          if (!mounted || generation != _generation || !widget.enabled) return;
          _source = refreshed;
          _loaded = false;
        } else if (expired) {
          throw StateError('재조회 필요');
        }
      }
      if (!mounted || generation != _generation || !widget.enabled) return;
      if (!_loaded) {
        // 인증 토큰을 signed URL의 외부 호스트로 보내지 않는다.
        final loading = _source.url.startsWith('asset:///')
            ? _player.setAsset(_source.url.substring(9))
            : _player.setUrl(_source.url);
        await loading.timeout(const Duration(seconds: 20));
        if (!mounted || generation != _generation || !widget.enabled) return;
        _loaded = true;
      }
      if (!mounted || generation != _generation || !widget.enabled) return;
      if (_player.processingState == ProcessingState.completed) {
        await _player.seek(Duration.zero);
      }
      if (!mounted || generation != _generation || !widget.enabled) return;
      setState(() {
        _loading = false;
        _error = null;
      });
      // play()는 재생이 끝나야 완료되므로 버튼 동작에서 기다리지 않는다.
      unawaited(
        _player.play().catchError((Object _) {
          if (generation == _generation) _showError();
        }),
      );
    } catch (_) {
      if (generation == _generation) _showError();
    }
  }

  @override
  void dispose() {
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_stateSubscription?.cancel());
    unawaited(_errorSubscription?.cancel());
    unawaited(_player.dispose());
    super.dispose();
  }

  String _time(Duration value) =>
      '${value.inMinutes}:${(value.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final playing =
        _player.playing && _player.processingState != ProcessingState.completed;
    final error = _error;
    // Figma WF-022: 진행 막대와 시간, 아래 큰 재생 버튼
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.label.isNotEmpty) ...[
          Text(
            widget.label,
            style: AppText.labelM.copyWith(color: AppColors.textBrand),
          ),
          const SizedBox(height: 12),
        ],
        StreamBuilder<Duration>(
          stream: _player.positionStream,
          builder: (context, snapshot) {
            final position = snapshot.data ?? Duration.zero;
            final duration = _player.duration ?? Duration.zero;
            final value = duration.inMilliseconds > 0
                ? position.inMilliseconds / duration.inMilliseconds
                : 0.0;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LinearProgressIndicator(
                  value: value.clamp(0.0, 1.0),
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_time(position), style: AppText.bodyS),
                    Text(_time(duration), style: AppText.bodyS),
                  ],
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: widget.enabled && !_loading ? _toggle : null,
          icon: Icon(playing ? Icons.pause : Icons.play_arrow),
          label: Text(
            _loading
                ? '소리 불러오는 중'
                : playing
                ? '멈추기'
                : error != null
                ? '다시 듣기'
                : '듣기',
          ),
        ),
        if (error != null) ...[const SizedBox(height: 12), ErrorText(error)],
      ],
    );
  }
}
