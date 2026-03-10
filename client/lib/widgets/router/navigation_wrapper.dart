import 'package:mydatatools/widgets/adaptive_app_bar.dart';
import 'package:mydatatools/widgets/collapsing_drawer.dart';
import 'package:mydatatools/widgets/router/status_message.dart';
import 'package:flutter/material.dart';

class NavigationWrapper extends StatefulWidget {
  const NavigationWrapper({super.key, required this.body, this.drawer});

  final Widget body;
  final Widget? drawer;

  @override
  State<NavigationWrapper> createState() => _NavigationWrapperState();
}

class _NavigationWrapperState extends State<NavigationWrapper> {
  final GlobalKey<ScaffoldState> appScaffold = GlobalKey<ScaffoldState>();

  // State variable: Managed by the hamburger icon. Defaults to true (open).
  bool _isSidebarLockedOpen = true;
  bool _drawerOpen = true;
  // Toggles the persistent state of the sidebar lock.
  void _toggleSidebarLock() {
    setState(() {
      _isSidebarLockedOpen = !_isSidebarLockedOpen;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      key: appScaffold,
      appBar: AdaptiveAppBar(
        onMenuPressed: () {
          setState(() => _toggleSidebarLock());
        },
        isSidebarLockedOpen: _isSidebarLockedOpen,
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CollapsingDrawer(isSidebarLockedOpen: _isSidebarLockedOpen),

                Expanded(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      (_drawerOpen && widget.drawer != null)
                          ? Container(
                              width: 250, 
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                border: Border(
                                  right: BorderSide(color: Colors.black12, width: 1.0),
                                ),
                              ),
                              child: widget.drawer,
                            )
                          : Container(),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16), // slightly more padding around the content
                          decoration: BoxDecoration(
                            color: theme.scaffoldBackgroundColor, // The gray background
                          ),
                          child: Container(
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8), // GCP style card radius
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 2.0,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                            child: widget.body,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 22,
            child: Container(
              padding: const EdgeInsets.only(left: 16),
              decoration: BoxDecoration(
                border: const Border(
                  top: BorderSide(width: 1.0, color: Colors.black12),
                ),
              ),
              child: const Row(children: [StatusMessage()]),
            ),
          ),
        ],
      ),
    );
  }
}
