Summary: Digital Mars D Compiler
Name: dmd
Version: 2.062
Release: 0
License: Proprietary
Group: Applications/Programming

Source0: dmd-%{version}-%{release}-%{_target_cpu}.pkg.tar.xz
URL: http://www.digitalmars.com/

Vendor: DigitalMars
Packager: <pwil3058@gmail.com>

#Prefix: we can't play with this without changing /etc/dmd.conf
#Requires: are picked up from the .PKGINFO file in the source

%description
Compiler for the D Programming language

%prep
if [ ! -f %{SOURCE0} ]; then
    wget --no-check-certificate -O %{SOURCE0} ftp://www.digitalmars.com/dmd-%{version}-%{release}-%{_target_cpu}.pkg.tar.xz
fi
rm -fr $RPM_BUILD_DIR/*
tar -xJvf %{SOURCE0}

%build
echo %{_target_cpu}

%install
echo install
rm -fr $RPM_BUILD_ROOT/*
mkdir -p $RPM_BUILD_ROOT
cp -r $RPM_BUILD_DIR/* $RPM_BUILD_ROOT/

%files
%defattr(755,root,root,-)
/usr/bin/*
%defattr(-,root,root,-)
/usr/lib/*
/usr/include/*
%doc /usr/share/*
%config /etc/bash_completion.d/dmd
%config /etc/dmd.conf

%clean

rm -fr $RPM_BUILD_ROOT
