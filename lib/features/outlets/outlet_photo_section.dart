import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/media/outlet_media_client.dart';
import '../../core/media/outlet_photo_picker.dart';
import '../../shared/widgets/app_card.dart';

class OutletPhotoSection extends StatefulWidget {
  const OutletPhotoSection({
    super.key,
    required this.routeCustomerId,
    required this.customerName,
    required this.mediaClient,
    required this.photoPicker,
    this.sessionId,
    this.onProfileChanged,
  });

  final String routeCustomerId;
  final String customerName;
  final String? sessionId;
  final OutletMediaClient mediaClient;
  final OutletPhotoPicker photoPicker;
  final ValueChanged<OutletMediaProfile>? onProfileChanged;

  @override
  State<OutletPhotoSection> createState() => _OutletPhotoSectionState();
}

class _OutletPhotoSectionState extends State<OutletPhotoSection> {
  OutletMediaProfile? _profile;
  List<OutletPhotoDraft> _drafts = const [];
  bool _loading = true;
  bool _picking = false;
  bool _saving = false;
  String? _deletingId;
  String? _message;

  int get _limit => _profile?.mediaLimit ?? outletMediaMaxPhotos;

  int get _remaining => (_limit -
          (_profile?.media.length ?? 0) -
          _drafts.length)
      .clamp(0, _limit)
      .toInt();

  bool get _busy =>
      _loading || _picking || _saving || (_deletingId ?? '').isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void didUpdateWidget(covariant OutletPhotoSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.routeCustomerId != widget.routeCustomerId ||
        oldWidget.mediaClient != widget.mediaClient) {
      _drafts = const [];
      _profile = null;
      _loadProfile();
    }
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final profile = await widget.mediaClient.loadProfile(
        routeCustomerId: widget.routeCustomerId,
      );
      if (!mounted) return;
      setState(() {
        _profile = profile;
      });
      widget.onProfileChanged?.call(profile);
    } on OutletMediaFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _profile = null;
        _message = failure.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _pickCamera() async {
    if (_busy || _remaining <= 0) return;
    setState(() {
      _picking = true;
      _message = null;
    });
    try {
      final draft = await widget.photoPicker.pickCamera();
      if (!mounted || draft == null) return;
      setState(() {
        _drafts = [..._drafts, draft].take(_limit).toList(growable: false);
      });
    } on OutletPhotoPickerFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _message = failure.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _picking = false;
        });
      }
    }
  }

  Future<void> _pickGallery() async {
    if (_busy || _remaining <= 0) return;
    setState(() {
      _picking = true;
      _message = null;
    });
    try {
      final additions = await widget.photoPicker.pickGallery(
        maxCount: _remaining,
      );
      if (!mounted || additions.isEmpty) return;
      setState(() {
        _drafts = [..._drafts, ...additions]
            .take(_limit)
            .toList(growable: false);
      });
    } on OutletPhotoPickerFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _message = failure.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _picking = false;
        });
      }
    }
  }

  void _removeDraft(String clientUploadId) {
    if (_busy) return;
    setState(() {
      _drafts = _drafts
          .where((item) => item.clientUploadId != clientUploadId)
          .toList(growable: false);
      _message = null;
    });
  }

  Future<void> _saveDrafts() async {
    if (_busy || _drafts.isEmpty) return;
    setState(() {
      _saving = true;
      _message = null;
    });

    final succeeded = <String>{};
    final failed = <String>{};
    try {
      for (final draft in List<OutletPhotoDraft>.from(_drafts)) {
        if (!mounted) return;
        setState(() {
          _drafts = _drafts
              .map(
                (item) => item.clientUploadId == draft.clientUploadId
                    ? item.copyWith(status: OutletPhotoStatus.uploading)
                    : item,
              )
              .toList(growable: false);
        });

        try {
          await widget.mediaClient.uploadPhoto(
            routeCustomerId: widget.routeCustomerId,
            sessionId: widget.sessionId,
            clientUploadId: draft.clientUploadId,
            bytes: draft.bytes,
            mimeType: draft.mimeType,
            width: draft.width,
            height: draft.height,
          );
          succeeded.add(draft.clientUploadId);
        } on OutletMediaFailure {
          failed.add(draft.clientUploadId);
        }
      }

      if (!mounted) return;
      setState(() {
        _drafts = _drafts
            .where((item) => !succeeded.contains(item.clientUploadId))
            .map(
              (item) => failed.contains(item.clientUploadId)
                  ? item.copyWith(status: OutletPhotoStatus.error)
                  : item,
            )
            .toList(growable: false);
      });

      await _loadProfile();
      if (!mounted) return;
      setState(() {
        _message = failed.isEmpty
            ? 'Đã bổ sung ${succeeded.length} ảnh cho điểm bán.'
            : 'Đã gửi ${succeeded.length} ảnh. Còn ${failed.length} ảnh lỗi, bấm Thử lại.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _deleteMedia(OutletMediaItem item) async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa ảnh điểm bán?'),
        content: const Text(
          'Ảnh này sẽ được xóa khỏi hồ sơ điểm bán.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Xóa ảnh'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _deletingId = item.id;
      _message = null;
    });
    try {
      await widget.mediaClient.deleteMedia(mediaId: item.id);
      await _loadProfile();
      if (!mounted) return;
      setState(() {
        _message = 'Đã xóa ảnh điểm bán.';
      });
    } on OutletMediaFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _message = failure.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _deletingId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = _profile?.media ?? const <OutletMediaItem>[];
    final failedDrafts = _drafts
        .where((item) => item.status == OutletPhotoStatus.error)
        .length;

    return AppCard(
      child: Column(
        key: const Key('outlet-photo-section'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ảnh điểm bán',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Tối đa 3 ảnh · ảnh được xử lý trước khi gửi',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              _PhotoCountBadge(
                loading: _loading,
                count: media.length,
                limit: _limit,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (_loading && _profile == null)
            const _MediaLoading()
          else if (media.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.lg,
              ),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.add_a_photo_outlined,
                    color: AppColors.textSecondary,
                    size: 28,
                  ),
                  SizedBox(height: AppSpacing.xs),
                  Text(
                    'Điểm bán chưa có ảnh cửa hàng.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              height: 112,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: media.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final item = media[index];
                  return _SavedPhotoCard(
                    item: item,
                    index: index,
                    deleting: _deletingId == item.id,
                    onDelete: _busy ? null : () => _deleteMedia(item),
                  );
                },
              ),
            ),
          if (_drafts.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Ảnh chờ gửi',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 118,
              child: ListView.separated(
                key: const Key('outlet-photo-drafts'),
                scrollDirection: Axis.horizontal,
                itemCount: _drafts.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final draft = _drafts[index];
                  return _DraftPhotoCard(
                    draft: draft,
                    onRemove: _busy
                        ? null
                        : () => _removeDraft(draft.clientUploadId),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              OutlinedButton.icon(
                key: const Key('outlet-photo-camera'),
                onPressed: _busy || _remaining <= 0 ? null : _pickCamera,
                icon: const Icon(Icons.photo_camera_outlined, size: 18),
                label: const Text('Chụp ảnh'),
              ),
              OutlinedButton.icon(
                key: const Key('outlet-photo-gallery'),
                onPressed: _busy || _remaining <= 0 ? null : _pickGallery,
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: const Text('Thư viện'),
              ),
              if (_drafts.isNotEmpty)
                FilledButton.icon(
                  key: const Key('outlet-photo-save'),
                  onPressed: _busy ? null : _saveDrafts,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          failedDrafts > 0
                              ? Icons.refresh_rounded
                              : Icons.cloud_upload_outlined,
                          size: 18,
                        ),
                  label: Text(
                    failedDrafts > 0
                        ? 'Thử lại ${_drafts.length} ảnh'
                        : 'Lưu ${_drafts.length} ảnh',
                  ),
                ),
            ],
          ),
          if (_remaining <= 0 && !_busy) ...[
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Đã đủ 3 ảnh. Muốn thay ảnh, hãy xóa ảnh cũ trước.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
          if ((_message ?? '').isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _message!,
              key: const Key('outlet-photo-message'),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PhotoCountBadge extends StatelessWidget {
  const _PhotoCountBadge({
    required this.loading,
    required this.count,
    required this.limit,
  });

  final bool loading;
  final int count;
  final int limit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: count > 0 ? AppColors.successSoft : AppColors.primarySoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        loading ? 'Đang tải' : '$count/$limit ảnh',
        style: TextStyle(
          color: count > 0 ? AppColors.success : AppColors.primary,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SavedPhotoCard extends StatelessWidget {
  const _SavedPhotoCard({
    required this.item,
    required this.index,
    required this.deleting,
    required this.onDelete,
  });

  final OutletMediaItem item;
  final int index;
  final bool deleting;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 112,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Image.network(
                item.viewUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: AppColors.background,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.broken_image_outlined,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 7,
            bottom: 7,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xB310233F),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Ảnh ${index + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          Positioned(
            right: 4,
            top: 4,
            child: IconButton.filledTonal(
              tooltip: 'Xóa ảnh',
              onPressed: onDelete,
              icon: deleting
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.close_rounded, size: 17),
              style: IconButton.styleFrom(
                minimumSize: const Size(32, 32),
                padding: EdgeInsets.zero,
                backgroundColor: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DraftPhotoCard extends StatelessWidget {
  const _DraftPhotoCard({
    required this.draft,
    required this.onRemove,
  });

  final OutletPhotoDraft draft;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final label = switch (draft.status) {
      OutletPhotoStatus.uploading => 'Đang gửi',
      OutletPhotoStatus.error => 'Gửi lỗi',
      OutletPhotoStatus.pending => 'Chờ gửi',
    };
    return SizedBox(
      width: 112,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Image.memory(draft.bytes, fit: BoxFit.cover),
            ),
          ),
          Positioned(
            left: 7,
            bottom: 7,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xC310233F),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          if (draft.status != OutletPhotoStatus.uploading)
            Positioned(
              right: 4,
              top: 4,
              child: IconButton.filledTonal(
                tooltip: 'Bỏ ảnh',
                onPressed: onRemove,
                icon: const Icon(Icons.close_rounded, size: 17),
                style: IconButton.styleFrom(
                  minimumSize: const Size(32, 32),
                  padding: EdgeInsets.zero,
                  backgroundColor: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MediaLoading extends StatelessWidget {
  const _MediaLoading();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 90,
      child: Center(child: CircularProgressIndicator()),
    );
  }
}
