import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AdaptiveAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AdaptiveAppBar({
    super.key,
    required this.onMenuPressed,
    this.isSidebarLockedOpen = true,
    isDesktop = !kIsWeb,
  });

  final VoidCallback onMenuPressed;
  final bool isSidebarLockedOpen;

  @override
  Size get preferredSize => const Size(300, 72);

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);
    final menuIcon =
        (isSidebarLockedOpen)
            ? Icon(Icons.menu_rounded)
            : Icon(Icons.menu_open_rounded);
    //final localizations = GalleryLocalizations.of(context)!;
    return PreferredSize(
      preferredSize: const Size.fromHeight(72.0),
      child: AppBar(
        toolbarHeight: 72,
        centerTitle: false,
        automaticallyImplyLeading: true,
        leading: IconButton(icon: menuIcon, onPressed: () => onMenuPressed()),
        leadingWidth: 70, //match nav bar
        title: const Text('My Data', style: TextStyle(color: Colors.black)),
        backgroundColor: themeData.scaffoldBackgroundColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.black),
            tooltip: 'User Settings',
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}
