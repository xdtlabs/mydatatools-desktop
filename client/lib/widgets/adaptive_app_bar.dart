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
            ? const Icon(Icons.menu_rounded, color: Colors.black54)
            : const Icon(Icons.menu_open_rounded, color: Colors.black54);
    //final localizations = GalleryLocalizations.of(context)!;
    return PreferredSize(
      preferredSize: const Size.fromHeight(64.0), // GCP is a bit shorter
      child: Container(
        decoration: BoxDecoration(
          color: themeData.scaffoldBackgroundColor, // Match the gray background
          border: const Border(
             bottom: BorderSide(color: Colors.black12, width: 1.0),
          )
        ),
        child: AppBar(
          toolbarHeight: 64,
          centerTitle: false,
          automaticallyImplyLeading: true,
          leading: IconButton(icon: menuIcon, onPressed: () => onMenuPressed()),
          leadingWidth: 70, //match nav bar
          title: Text(
            'My Data', 
            style: themeData.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w400,
              color: Colors.black87,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.settings, color: Colors.black54),
              tooltip: 'User Settings',
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }
}
