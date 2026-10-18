#
# spec file for package kwin-effects-better-blur-dx
#
# Packaging is MIT licensed; see LICENSE in
# https://github.com/kanonmaten/better-blur-dx-rpm
#
# The upstream tarball is fetched by _service (download_url) and checked
# against src_sha256 in %%prep. scripts/bump-version.sh keeps Version,
# src_sha256 and _service in step.
#

%global src_sha256 ab205ef7ca700cfe8cdb8201934b59a9d734ddf3a98afc5cdf65b153538fe497

# KWin only loads an effect built for its exact version: it compares the
# plugin IID "org.kde.kwin.EffectPluginFactory<version>" and skips the effect
# on a mismatch. Pin kwin6 to the version this build saw, so zypper never
# pairs a new KWin with a stale plugin. OBS rebuilds this package by itself
# whenever kwin6-devel changes in Tumbleweed, and the changed Requires makes
# sure that rebuild gets published.
%global kwin_version %(rpm -q --qf '%%{VERSION}' kwin6-devel 2>/dev/null | grep -E '^[0-9]' || echo 0)

Name:           kwin-effects-better-blur-dx
Version:        2.6.0
Release:        0
Summary:        KWin blur effect with force blur, rounded corners and refraction
License:        GPL-2.0-or-later AND GPL-3.0-only
URL:            https://github.com/xarblu/kwin-effects-better-blur-dx
Source0:        %{name}-%{version}.tar.gz
BuildRequires:  cmake
BuildRequires:  gcc-c++
BuildRequires:  kf6-extra-cmake-modules
BuildRequires:  kwin6-devel
BuildRequires:  cmake(KDecoration3)
BuildRequires:  cmake(KF6ColorScheme)
BuildRequires:  cmake(KF6Config)
BuildRequires:  cmake(KF6ConfigWidgets)
BuildRequires:  cmake(KF6CoreAddons)
BuildRequires:  cmake(KF6I18n)
BuildRequires:  cmake(KF6KCMUtils)
BuildRequires:  cmake(KF6WidgetsAddons)
BuildRequires:  cmake(KF6WindowSystem)
BuildRequires:  cmake(Qt6Core)
BuildRequires:  cmake(Qt6DBus)
BuildRequires:  cmake(Qt6Gui)
BuildRequires:  cmake(Qt6Network)
BuildRequires:  cmake(Qt6OpenGL)
BuildRequires:  cmake(Qt6Qml)
BuildRequires:  cmake(Qt6Quick)
BuildRequires:  cmake(Qt6Widgets)
BuildRequires:  pkgconfig(epoxy)
BuildRequires:  pkgconfig(x11)
BuildRequires:  pkgconfig(xcb)
Requires:       kwin6 = %{kwin_version}
# Same effect from home:Mx775:Plasma; both ship better_blur_dx.so.
Conflicts:      better-blur-dx
ExcludeArch:    %{ix86}

%description
Better Blur DX is a fork of the KDE Plasma 6 blur effect. On top of the
stock blur it can force blur onto windows that don't request it, round the
blurred corners, add refraction and a wallpaper-only mode.

Enable it in System Settings > Window Management > Desktop Effects, and turn
off the stock Blur effect, which it replaces.

This build is for KWin on Wayland only. It is tied to the KWin version it
was compiled against and is rebuilt automatically when KWin updates.

%prep
echo '%{src_sha256}  %{SOURCE0}' | sha256sum -c -
%autosetup -p1

%build
# Fail loudly instead of shipping "Requires: kwin6 = 0".
test "%{kwin_version}" != 0
%cmake_kf6
%kf6_build

%install
%kf6_install

%files
%license LICENSE
%doc README.md CHANGELOG.md
# Only kwin6 (not kwin6-devel, which is all the build root has) owns most of
# these, and nothing owns effects/plugins since KWin's own effects are built
# in. Co-own the whole chain so the filelist check passes.
%dir %{_kf6_plugindir}/kwin
%dir %{_kf6_plugindir}/kwin/effects
%dir %{_kf6_plugindir}/kwin/effects/configs
%dir %{_kf6_plugindir}/kwin/effects/plugins
%{_kf6_plugindir}/kwin/effects/plugins/better_blur_dx.so
%{_kf6_plugindir}/kwin/effects/configs/kwin_better_blur_dx_config.so

%changelog
* Sun Oct 18 2026 kanonmaten <86723077+kanonmaten@users.noreply.github.com> - 2.6.0-0
- Initial package of upstream 2.6.0
- Wayland only: KWin X11 is no longer in Tumbleweed as of Plasma 6.8
- Pin kwin6 to the exact version the effect was built against
