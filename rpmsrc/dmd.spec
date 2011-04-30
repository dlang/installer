Summary: Digital Mars D Compiler
Name: dmd
Version: 2.052
Release: 0
License: Proprietary
Group: Applications/Programming

# These are horrible, terrible names. Just so you know.
Source0: D-Programming-Language-dmd-dmd-2.052-0-gf8ed1b3.tar.gz
Source1: D-Programming-Language-phobos-phobos-2.052-0-g18cdcdc.tar.gz
Source2: D-Programming-Language-druntime-druntime-2.052-0-gbc731e9.tar.gz
Source3: dmd.conf
Source4: d-completion.sh
BuildRoot:      %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
URL: http://www.digitalmars.com/

Patch1: dmd-2.052-libm.patch
Patch2: dmd-2.052-phobos-paths.patch
Patch3: dmd-2.052-druntime-paths.patch

Vendor: DigitalMars
Packager: <kai@gnukai.com>

#Prefix: /usr/local
#Requires: libstdc++5
ExclusiveArch: i386

%description
Compiler for the D Programming language

%prep
rm -fr D-Programming-Language-dmd-df42e28/ 
rm -fr D-Programming-Language-phobos-9869e60/
rm -fr D-Programming-Language-druntime-715b0be/ 
if [ ! -f %{SOURCE0} ]; then
    wget --no-check-certificate -O %{SOURCE0} https://github.com/D-Programming-Language/dmd/tarball/dmd-2.052
fi
if [ ! -f %{SOURCE1} ]; then
    wget --no-check-certificate -O %{SOURCE1} https://github.com/D-Programming-Language/phobos/tarball/phobos-2.052
fi
if [ ! -f %{SOURCE2} ]; then
    wget --no-check-certificate -O %{SOURCE2} https://github.com/D-Programming-Language/druntime/tarball/druntime-2.052
fi
tar -xzvf %{SOURCE0}
tar -xzvf %{SOURCE1}
tar -xzvf %{SOURCE2}

%patch1
%patch2
%patch3

%build
echo %{_target_cpu}
cd $RPM_BUILD_DIR/D-Programming-Language-dmd-df42e28/src/
make -f linux.mak
cd $RPM_BUILD_DIR/D-Programming-Language-phobos-9869e60/
make -f posix.mak
## Phobos will build druntime
#cd $RPM_BUILD_DIR/D-Programming-Language-druntime-715b0be/
#make -f posix.mak

%install
echo install
rm -fr $RPM_BUILD_ROOT
mkdir -p $RPM_BUILD_ROOT%{_bindir} \
         $RPM_BUILD_ROOT%{_libdir} \
         $RPM_BUILD_ROOT%{_docdir}/dmd \
         $RPM_BUILD_ROOT/usr/share/dmd \
         $RPM_BUILD_ROOT/usr/include/d/dmd/druntime/ \
         $RPM_BUILD_ROOT/usr/include/d/dmd/phobos/ \
         $RPM_BUILD_ROOT/etc/bash_completion.d/ 
cp -r $RPM_BUILD_DIR/D-Programming-Language-druntime-715b0be/import $RPM_BUILD_ROOT/usr/include/d/dmd/druntime/
cp -r $RPM_BUILD_DIR/D-Programming-Language-dmd-df42e28/docs/man/man1 $RPM_BUILD_ROOT%{_mandir}
cp -r $RPM_BUILD_DIR/D-Programming-Language-druntime-715b0be/doc $RPM_BUILD_ROOT%{_docdir}/dmd
cp -r $RPM_BUILD_DIR/D-Programming-Language-phobos-9869e60/{etc,std,*.d} $RPM_BUILD_ROOT/usr/include/d/dmd/phobos/
cp $RPM_BUILD_DIR/D-Programming-Language-dmd-df42e28/src/dmd $RPM_BUILD_ROOT%{_bindir}/dmd
cp $RPM_BUILD_DIR/D-Programming-Language-phobos-9869e60/generated/linux/release/32/libphobos2.a $RPM_BUILD_ROOT%{_libdir}
cp $RPM_SOURCE_DIR/dmd.conf $RPM_BUILD_ROOT/etc
cp $RPM_SOURCE_DIR/d-completion.sh $RPM_BUILD_ROOT/etc/bash_completion.d/
# These were included in the dmd-2.051 rpm, but I don't see them anywhere after running the 2 Make files for dmd and phobos
#cp $RPM_BUILD_DIR/D-Programming-Language-dmd-df42e28/src/dumpobj $RPM_BUILD_ROOT%{_bindir}/dumpobj
#cp $RPM_BUILD_DIR/D-Programming-Language-dmd-df42e28/src/obj2asm $RPM_BUILD_ROOT%{_bindir}/obj2asm
#cp $RPM_BUILD_DIR/D-Programming-Language-dmd-df42e28/src/rdmd $RPM_BUILD_ROOT%{_bindir}/rdmd

#////////////////////////////////////////////////////////////////
%files
#
# list all files that need to be copied here
#

%defattr(755,root,root,-)
/usr/bin/dmd
# These were included in the dmd-2.051 rpm, but I don't see them anywhere after running the 2 Make files for dmd and phobos
#/usr/bin/dumpobj
#/usr/bin/obj2asm
#/usr/bin/rdmd
%defattr(-,root,root,-)
/usr/include/d/dmd
/usr/lib/libphobos2.a
%doc /usr/share/man
%doc /usr/share/doc/dmd
%doc /usr/share/dmd
%config /etc/bash_completion.d/d-completion.sh
%config /etc/dmd.conf

%clean

# I'm not sure that RPM->DEB conversion is the "best" way, particularly since it requires "root" privileges for most packages.
# Building RPMs as a privileged user is generally frowned upon.
#convert to DEB if alien is detected
#ALIEN=""
#if which alien; then
#    ALIEN=`which alien 2>/dev/null`
#fi
#if test -n "$ALIEN"; then
#    if test -z $RPM_RPMS_DIR; then
#        RPM_RPMS_DIR=`readlink -f "$RPM_BUILD_DIR/../RPMS"`
#    fi
#    cd $RPM_RPMS_DIR/%_arch/
#    $ALIEN -k --scripts $RPM_RPMS_DIR/%_arch/dmd-%{version}-041111.%_arch.rpm
#
#    cp $RPM_RPMS_DIR/%_arch/dmd_%{version}-041111_*.deb $MY_WORK_DIR
#fi
#cp $RPM_RPMS_DIR/%_arch/dmd-%{version}-041111.%_arch.rpm $MY_WORK_DIR

#%pre
#if test -z "$RPM_INSTALL_PREFIX"; then
#    RPM_INSTALL_PREFIX=/usr/local
#fi

#%post

%changelog
* Thu Apr 14 2010 Kai Meyer <kai@gnukai.com>
- Removed the if statement around the arch restrictions, and limit to just i386 period.

* Wed Apr 13 2010 Kai Meyer <kai@gnukai.com>
- Added a 'wget' for the source files if they don't exist during "prep". This takes us one step closer to building completely from the spec file.

* Tue Apr 12 2010 Kai Meyer <kai@gnukai.com>
- Initial hack at the rpm. Build works, all files appear to be in-place. Some of my non-trivial D projects compile and work fine.
- There are currently no dependancies on the build or resulting package. 
- This generates one monolithic RPM, and it appears obvious we could generate one for dmd, one for phobos, and one for druntime, and keep them updated separately.

