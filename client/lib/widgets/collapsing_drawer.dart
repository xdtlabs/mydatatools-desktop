import 'dart:async';

import 'package:mydatatools/app_constants.dart';
import 'package:mydatatools/models/tables/app.dart' as m;
import 'package:mydatatools/services/get_apps_service.dart';
import 'package:mydatatools/services/get_user_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';

class CollapsingDrawer extends StatefulWidget {
  final bool isSidebarLockedOpen;
  const CollapsingDrawer({super.key, this.isSidebarLockedOpen = true});

  @override
  State<CollapsingDrawer> createState() => _CollapsingDrawerState();
}

class _CollapsingDrawerState extends State<CollapsingDrawer>
    with SingleTickerProviderStateMixin {
  final double maxWidth = 250;
  final double minWidth = 60;
  bool isCollapsed = false;
  bool isLoading = true;
  Animation<double>? widthAnimation;
  int currentSelectedIndex = 0;
  GetAppsService? _getAppsService;
  StreamSubscription? _appsSub;
  StreamSubscription? _loadingSub;
  List<m.App> apps = [];

  @override
  void initState() {
    super.initState();


    /////////////////////////////////////////////////
    // Load Apps
    _getAppsService = GetAppsService.instance;
    //flag to hide/show loading icon
    _loadingSub = _getAppsService!.isLoading.listen((value) {
      if (context.mounted) {
        setState(() {
          isLoading = value;
        });
      }
    });
    //list of all apps
    _appsSub = _getAppsService!.sink.listen((value) {
      if( context.mounted ) {
        setState(() {
          apps = value;
        });
      }
    });

    _getAppsService!.invoke(GetAppsServiceCommand());
  }

  @override
  void dispose() {
    //_animationController?.dispose();
    _appsSub?.cancel();
    _loadingSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    //final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final theme = Theme.of(context);
    double iconPadding = isCollapsed ? 16.0 : 16.0;

    isCollapsed = widget.isSidebarLockedOpen;
    final double currentWidth = isCollapsed
        ? minWidth
        : maxWidth;

    var collectionApps = apps.where((e) => e.group == 'collections').toList();
    var appApps = apps.where((e) => e.group == 'app').toList();

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }


    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      width: currentWidth,
      color: theme.scaffoldBackgroundColor,
      child: SizedBox(
        width: currentWidth,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(color: theme.dividerColor, width: 1),
            ),
          ),
          child: Column(
            // Important: Remove any padding from the ListView.
            //padding: EdgeInsets.zero,
            children: [
              ListTile(
                leading: Icon(
                  Icons.home,
                  size: 24.0,
                  color: theme.colorScheme.primary,
                ),
                title: isCollapsed ? null : const Text('Home'),
                contentPadding: EdgeInsets.symmetric(horizontal: iconPadding),
                onTap: () {
                  GoRouter.of(context).go("/");
                },
              ),



              /// Apps build to work with the different locations
              SizedBox(
                height: 38,
                child: ListTile(
                  title:
                  isCollapsed
                      ? const Text('')
                      : const Text('Applications'),
                  onTap: null,
                ),
              ),
              ...appApps.map((app) {
                return ListTile(
                  leading: Icon(
                    IconData(app.icon ?? 0xe08f, fontFamily: 'MaterialIcons'),
                    size: 24.0,
                    color: theme.colorScheme.primary,
                  ),
                  title: isCollapsed ? null : Text(app.name, softWrap: false),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: iconPadding,
                  ),
                  onTap: () {
                    GoRouter.of(context).go(app.route);
                  },
                );
              }),




              /// List of different collection apps
              SizedBox(
                height: 38,
                child: ListTile(
                  title:
                      isCollapsed
                          ? const Text('')
                          : const Text('Collections'),
                  onTap: null,
                ),
              ),


              ...collectionApps.map((app) {
                return ListTile(
                  leading: Icon(
                    IconData(app.icon ?? 0xe08f, fontFamily: 'MaterialIcons'),
                    size: 24.0,
                    color: theme.colorScheme.primary,
                  ),
                  title: isCollapsed ? null : Text(app.name, softWrap: false),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: iconPadding,
                  ),
                  onTap: () {
                    GoRouter.of(context).go(app.route);
                  },
                );
              }),


              const Spacer(),
              Divider(color: theme.dividerColor, height: 4.0),
              ListTile(
                leading: Icon(
                  Icons.logout,
                  size: 24.0,
                  color: theme.colorScheme.primary,
                ),
                title: isCollapsed ? null : const Text('Logout'),
                contentPadding: EdgeInsets.symmetric(horizontal: iconPadding),
                onTap: () async {
                  //clear local provider
                  GetUserService.instance.invoke(GetUserServiceCommand(null));

                  //clear remembered password
                  FlutterSecureStorage storage = const FlutterSecureStorage();
                  await storage.write(
                    key: AppConstants.securePassword,
                    value: null,
                  );

                  //reload router
                  if( context.mounted ) {
                    GoRouter.of(context).go('/?action=logout');
                  }
                },
              ),
              /**
                  Align(
                    alignment: Alignment.centerRight,
                    child: InkWell(
                        onTap: () {
                          setState(() {
                            isCollapsed = !isCollapsed;
                            isCollapsed
                                ? _animationController?.forward()
                                : _animationController?.reverse();
                          });
                        },
                        child: isCollapsed
                            ? const Icon(Icons.last_page)
                            : const Icon(Icons.first_page)),
                  ),
                  **/
              const SizedBox(height: 10.0),
            ],
          ),
        ),
      ),
    );
  }
}
