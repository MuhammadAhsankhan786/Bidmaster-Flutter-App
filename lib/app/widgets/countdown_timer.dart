import 'package:flutter/material.dart';
import 'dart:async';
import '../theme/colors.dart';

enum CountdownSize { small, medium, large }

class CountdownTimer extends StatefulWidget {
  final DateTime endTime;
  final CountdownSize size;

  const CountdownTimer({
    super.key,
    required this.endTime,
    this.size = CountdownSize.medium,
  });

  @override
  State<CountdownTimer> createState() => _CountdownTimerState();
}

class _CountdownTimerState extends State<CountdownTimer> {
  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateTimer();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateTimer();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateTimer() {
    final now = DateTime.now();
    final difference = widget.endTime.difference(now);

    if (difference.isNegative) {
      setState(() {
        _remaining = Duration.zero;
      });
      _timer?.cancel();
    } else {
      setState(() {
        _remaining = difference;
      });
    }
  }

  Color _getColor() {
    final totalHours = _remaining.inHours;
    if (totalHours < 1) return AppColors.red500;
    if (totalHours < 24) return AppColors.yellow600;
    return AppColors.green600;
  }

  Color _getBackgroundColor(BuildContext context) {
    final totalHours = _remaining.inHours;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (totalHours < 1) {
      return isDark ? AppColors.red950 : AppColors.red50;
    }
    if (totalHours < 24) {
      return isDark ? AppColors.yellow950 : AppColors.yellow50;
    }
    return isDark ? AppColors.green950 : AppColors.green50;
  }

  double _getFontSize() {
    switch (widget.size) {
      case CountdownSize.small:
        return 10;
      case CountdownSize.medium:
        return 12;
      case CountdownSize.large:
        return 14;
    }
  }

  double _getPadding() {
    switch (widget.size) {
      case CountdownSize.small:
        return 8;
      case CountdownSize.medium:
        return 12;
      case CountdownSize.large:
        return 16;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_remaining.isNegative || _remaining.inSeconds <= 0) {
      return Container(
        padding: EdgeInsets.all(_getPadding()),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.slate800
              : AppColors.slate100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.access_time, size: 12, color: AppColors.slate500),
            const SizedBox(width: 4),
            Text(
              'Ended',
              style: TextStyle(
                fontSize: _getFontSize(),
                color: AppColors.slate500,
              ),
            ),
          ],
        ),
      );
    }

    final hours = _remaining.inHours;
    final minutes = _remaining.inMinutes % 60;
    final seconds = _remaining.inSeconds % 60;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: _getPadding(),
        vertical: _getPadding() / 2,
      ),
      decoration: BoxDecoration(
        color: _getBackgroundColor(context),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.access_time,
            size: 12,
            color: _getColor(),
          ),
          const SizedBox(width: 6),
          Text(
            '${hours.toString().padLeft(2, '0')}:'
            '${minutes.toString().padLeft(2, '0')}:'
            '${seconds.toString().padLeft(2, '0')}',
            style: TextStyle(
              fontSize: _getFontSize(),
              fontWeight: FontWeight.bold,
              color: _getColor(),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

