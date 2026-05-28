import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class FlagTray extends StatefulWidget {
  final String currentIsoCode;
  final String countryName;
  final GlobalKey cardKey;

  const FlagTray({
    super.key,
    required this.currentIsoCode,
    required this.countryName,
    required this.cardKey,
  });

  @override
  State<FlagTray> createState() => FlagTrayState();
}

class FlagTrayState extends State<FlagTray> with SingleTickerProviderStateMixin {
  late AnimationController _bounceController;
  late Animation<Offset> _bounceAnim;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _bounceAnim = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(20, -10),
    ).animate(CurvedAnimation(parent: _bounceController, curve: Curves.elasticOut));
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  /// Plays the bounce-back animation (called when a wrong drop occurs).
  void triggerBounce() {
    _bounceController.forward().then((_) => _bounceController.reverse());
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      color: Colors.grey.shade200,
      child: Center(
        child: AnimatedBuilder(
          animation: _bounceAnim,
          builder: (ctx, child) => Transform.translate(
            offset: _bounceAnim.value,
            child: child,
          ),
          child: _buildDraggableCard(),
        ),
      ),
    );
  }

  Widget _buildDraggableCard() {
    return Draggable<String>(
      data: widget.currentIsoCode,
      feedback: Material(elevation: 4, child: _card()),
      childWhenDragging: Opacity(opacity: 0.3, child: _card()),
      child: _card(),
    );
  }

  Widget _card() {
    return Container(
      key: widget.cardKey,
      width: 90,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(blurRadius: 4, offset: Offset(2, 2), color: Color(0x44000000)),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              child: SvgPicture.asset(
                'assets/flags/${widget.currentIsoCode.toLowerCase()}.svg',
                fit: BoxFit.cover,
                width: 90,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              widget.countryName,
              style: const TextStyle(fontSize: 10),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
