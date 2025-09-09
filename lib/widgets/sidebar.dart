import 'package:flutter/material.dart';

/// ---------- Public API ----------

sealed class SideNavEntry {
  const SideNavEntry();
}

class SideNavItem extends SideNavEntry {
  final IconData icon;
  final String label;
  final String? badge;
  final Widget Function()? trailingBuilder;
  SideNavItem({
    required this.icon,
    required this.label,
    this.badge,
    this.trailingBuilder,
  });
}

class SideNavHeader extends SideNavEntry {
  final String label;
  final Widget Function()? trailingBuilder;

  const SideNavHeader({required this.label, this.trailingBuilder});
}

class SideNavDivider extends SideNavEntry {
  const SideNavDivider();
}

class SideNavSpace extends SideNavEntry {
  final double spacing;

  const SideNavSpace(this.spacing);
}

class SideNav extends StatelessWidget {
  final List<SideNavEntry> entries;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// Layout
  final bool extended;
  final double collapsedWidth;
  final double expandedWidth;
  final double itemHeight;
  final double iconSize;
  final double iconLabelSpacing;
  final EdgeInsetsGeometry itemPadding;

  /// Colors & styles
  final Color? backgroundColor;
  final Color? selectedColor;
  final Color? hoverColor;
  final TextStyle? itemTextStyle;
  final TextStyle? headerTextStyle;
  final double radius;

  /// Animations
  final Duration animationDuration;

  const SideNav({
    super.key,
    required this.entries,
    required this.selectedIndex,
    required this.onSelected,
    this.extended = true,
    this.collapsedWidth = 72,
    this.expandedWidth = 240,
    this.itemHeight = 44,
    this.iconSize = 22,
    this.iconLabelSpacing = 12,
    this.itemPadding = const EdgeInsets.symmetric(horizontal: 12),
    this.backgroundColor,
    this.selectedColor,
    this.hoverColor,
    this.itemTextStyle,
    this.headerTextStyle,
    this.radius = 12,
    this.animationDuration = const Duration(milliseconds: 180),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = backgroundColor ?? theme.colorScheme.surface;
    final sel = selectedColor ?? theme.colorScheme.primary.withOpacity(0.12);
    final hov = hoverColor ?? theme.colorScheme.surfaceVariant.withOpacity(0.5);
    final txt =
        itemTextStyle ??
        theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface,
        );
    final headTxt =
        headerTextStyle ??
        theme.textTheme.labelSmall?.copyWith(
          letterSpacing: 0.6,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface.withOpacity(0.6),
        );

    return AnimatedContainer(
      duration: animationDuration,
      width: extended ? expandedWidth : collapsedWidth,
      decoration: BoxDecoration(color: bg),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 6),
              itemCount: entries.length,
              itemBuilder: (context, i) {
                final e = entries[i];
                if (e is SideNavDivider) {
                  return Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: extended ? 12 : 8,
                      vertical: 8,
                    ),
                    child: Divider(height: 1),
                  );
                }
                if (e is SideNavHeader) {
                  return _Header(
                    label: e.label,
                    extended: extended,
                    style: headTxt!,
                    trailingBuilder: e.trailingBuilder,
                  );
                }
                if (e is SideNavSpace) {
                  return SizedBox(height: e.spacing);
                }
                final item = e as SideNavItem;
                final selected = i == selectedIndex;
                return _ItemTile(
                  item: item,
                  index: i,
                  selected: selected,
                  onTap: () {
                    onSelected(i);
                  },
                  extended: extended,
                  itemHeight: itemHeight,
                  iconSize: iconSize,
                  spacing: iconLabelSpacing,
                  padding: itemPadding,
                  textStyle: txt!,
                  selectedColor: sel,
                  hoverColor: hov,
                  radius: radius,
                  duration: animationDuration,
                  trailingBuilder: e.trailingBuilder,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// ---------- Internals ----------

class _Header extends StatelessWidget {
  final String label;
  final bool extended;
  final TextStyle style;
  final Widget Function()? trailingBuilder;
  const _Header({
    required this.label,
    required this.extended,
    required this.style,
    this.trailingBuilder,
  });

  @override
  Widget build(BuildContext context) {
    if (!extended) return const SizedBox(height: 8);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      child: Row(
        children: [
          Text(label.toUpperCase(), style: style),
          Spacer(),
          if (trailingBuilder != null) trailingBuilder!(),
        ],
      ),
    );
  }
}

class _ItemTile extends StatefulWidget {
  final SideNavItem item;
  final int index;
  final bool selected;
  final VoidCallback onTap;
  final bool extended;
  final double itemHeight;
  final double iconSize;
  final double spacing;
  final EdgeInsetsGeometry padding;
  final TextStyle textStyle;
  final Color selectedColor;
  final Color hoverColor;
  final double radius;
  final Duration duration;
  Widget Function()? trailingBuilder;

  _ItemTile({
    required this.item,
    required this.index,
    required this.selected,
    required this.onTap,
    required this.extended,
    required this.itemHeight,
    required this.iconSize,
    required this.spacing,
    required this.padding,
    required this.textStyle,
    required this.selectedColor,
    required this.hoverColor,
    required this.radius,
    required this.duration,
    this.trailingBuilder,
  });

  @override
  State<_ItemTile> createState() => _ItemTileState();
}

class _ItemTileState extends State<_ItemTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = theme.colorScheme.onSurface;
    final iconColor = widget.selected
        ? theme.colorScheme.primary
        : fg.withOpacity(0.85);

    final row = Row(
      children: [
        Icon(widget.item.icon, size: widget.iconSize, color: iconColor),
        if (widget.extended) SizedBox(width: widget.spacing),
        if (widget.extended)
          Expanded(
            child: Row(
              children: [
                // Expanded(
                Text(widget.item.label, style: widget.textStyle),

                // ),
                Spacer(),

                if (widget.item.badge != null)
                  _Badge(text: widget.item.badge!, theme: theme),
                if (widget.trailingBuilder != null) widget.trailingBuilder!(),
              ],
            ),
          ),
      ],
    );

    final tile = AnimatedContainer(
      duration: widget.duration,
      height: widget.itemHeight,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: widget.selected
            ? widget.selectedColor
            : _hover
            ? widget.hoverColor
            : Colors.transparent,
        borderRadius: BorderRadiusGeometry.circular(widget.radius),
      ),
      child: row,
    );

    final content = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(widget.radius),
        onTap: widget.onTap,
        child: MouseRegion(
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: tile,
        ),
      ),
    );

    // Show tooltip when collapsed
    return widget.extended
        ? Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: content,
          )
        : Tooltip(
            message: widget.item.label,
            waitDuration: const Duration(milliseconds: 400),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: content,
            ),
          );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final ThemeData theme;
  const _Badge({required this.text, required this.theme});

  @override
  Widget build(BuildContext context) {
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: cs.onSecondaryContainer,
        ),
      ),
    );
  }
}
