import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:flags_around_the_world/generated/l10n/app_localizations.dart';

class FlagTray extends StatefulWidget {
  final String currentIsoCode;
  final String countryName;
  final GlobalKey cardKey;
  final bool showName;
  final int hintsRemaining;
  final VoidCallback onHintPressed;

  const FlagTray({
    super.key,
    required this.currentIsoCode,
    required this.countryName,
    required this.cardKey,
    this.showName = true,
    this.hintsRemaining = 2,
    this.onHintPressed = _noOp,
  });

  static void _noOp() {}

  // The point within the feedback widget that sits at the pointer during drag.
  // DragTargetDetails.offset = pointer_global − kPinAnchor, so callers must
  // add this back to recover the actual drop coordinate.
  static const kPinAnchor = Offset(45, 70);

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

  void triggerBounce() {
    _bounceController.forward().then((_) => _bounceController.reverse());
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      color: Colors.grey.shade200,
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHintButton(context),
            const SizedBox(width: 8),
            AnimatedBuilder(
              animation: _bounceAnim,
              builder: (ctx, child) => Transform.translate(
                offset: _bounceAnim.value,
                child: child,
              ),
              child: _buildDraggableCard(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHintButton(BuildContext context) {
    return Tooltip(
      message: AppLocalizations.of(context).hintTooltip,
      child: ElevatedButton.icon(
        onPressed: widget.onHintPressed,
        icon: const Icon(Icons.lightbulb_outline, size: 18),
        label: Text('Hint ×${widget.hintsRemaining}'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),
    );
  }

  Widget _buildDraggableCard() {
    return Draggable<String>(
      data: widget.currentIsoCode,
      // Anchor the pin tip (bottom-centre of feedback) to the pointer so the
      // user drops on the country with the visible tip, not a card corner.
      dragAnchorStrategy: _pinAnchorStrategy,
      feedback: _buildFeedback(),
      // GlobalKey is only on `child` — feedback and childWhenDragging must NOT
      // share it, or Flutter throws a duplicate-GlobalKey error during the drag.
      childWhenDragging: Opacity(opacity: 0.3, child: _cardShell()),
      child: _cardShell(key: widget.cardKey),
    );
  }

  // Anchor point = tip of the pin triangle = kPinAnchor within the feedback.
  // Width 90 → centre x = 45; card height 60 + triangle height 10 → tip y = 70.
  static Offset _pinAnchorStrategy(
    Draggable<Object> draggable,
    BuildContext context,
    Offset position,
  ) =>
      FlagTray.kPinAnchor;

  Widget _buildFeedback() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Material(
          elevation: 6,
          borderRadius: BorderRadius.circular(8),
          child: _cardShell(),
        ),
        // Pin tip — the actual drop-registration point.
        // The player aligns this triangle with the target country.
        ClipPath(
          clipper: const _DownTriangle(),
          child: Container(
            width: 20,
            height: 10,
            color: const Color(0xFFFF6600),
          ),
        ),
      ],
    );
  }

  // Card shell — optionally keyed.  Content is always the same.
  // Separating key from content prevents the GlobalKey from appearing in
  // both the Overlay (feedback) and the widget tree (childWhenDragging)
  // simultaneously.
  Widget _cardShell({Key? key}) {
    return Container(
      key: key,
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
          if (widget.showName)
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

// Downward-pointing triangle clipper for the pin tip.
class _DownTriangle extends CustomClipper<Path> {
  const _DownTriangle();

  @override
  Path getClip(Size size) => Path()
    ..moveTo(0, 0)
    ..lineTo(size.width, 0)
    ..lineTo(size.width / 2, size.height)
    ..close();

  @override
  bool shouldReclip(_DownTriangle old) => false;
}
