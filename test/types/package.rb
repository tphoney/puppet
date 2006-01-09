if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $puppetbase = "../.."
end

require 'puppettest'
require 'puppet'
require 'test/unit'
require 'facter'

$platform = Facter["operatingsystem"].value

unless Puppet.type(:package).default
    puts "No default package type for %s; skipping package tests" % $platform
else

class TestPackageSource < Test::Unit::TestCase
	include TestPuppet
    def test_filesource
        path = tempfile()
        system("touch %s" % path)
        assert_equal(
            path,
            Puppet::PackageSource.get("file://#{path}")
        )
    end
end

class TestPackages < Test::Unit::TestCase
	include FileTesting
    def setup
        super
        #@list = Puppet.type(:package).getpkglist
        Puppet.type(:package).clear
    end

    # These are packages that we're sure will be installed
    def installedpkgs
        pkgs = nil
        case $platform
        when "SunOS"
            pkgs = %w{SMCossh}
        when "Debian": pkgs = %w{ssh openssl}
        when "Fedora": pkgs = %w{openssh}
        else
            Puppet.notice "No test package for %s" % $platform
            return []
        end

        return pkgs
    end

    def tstpkg
        case $platform
        #when "SunOS"
        #    type = "sunpkg"
        when "Debian":
            return %w{zec}
        #when "RedHat": type = :rpm
        when "Fedora":
            return %w{wv}
        else
            Puppet.notice "No test packags for %s" % $platform
            return nil
        end
    end

    def mkpkgcomp(pkg)
        assert_nothing_raised {
            pkg = Puppet.type(:package).create(:name => pkg, :install => true)
        }
        assert_nothing_raised {
            pkg.retrieve
        }

        comp = newcomp("package", pkg)

        return comp
    end

    def test_retrievepkg
        installedpkgs().each { |pkg|
            obj = nil
            assert_nothing_raised {
                obj = Puppet.type(:package).create(
                    :name => pkg
                )
            }

            assert(obj, "could not create package")

            assert_nothing_raised {
                obj.retrieve
            }

            assert(obj.is(:install), "Could not retrieve package version")
        }
    end

    def test_nosuchpkg
        obj = nil
        assert_nothing_raised {
            obj = Puppet.type(:package).create(
                :name => "thispackagedoesnotexist"
            )
        }

        assert_nothing_raised {
            obj.retrieve
        }

        assert_equal(:notinstalled, obj.is(:install),
            "Somehow retrieved unknown pkg's version")
    end

    def test_latestpkg
        pkgs = tstpkg || return

        pkgs.each { |name|
            pkg = Puppet.type(:package).create(:name => name)
            assert_nothing_raised {
                assert(pkg.latest, "Package did not return value for 'latest'")
            }
        }
    end

    unless Process.uid == 0
        $stderr.puts "Run as root to perform package installation tests"
    else
    def test_installpkg
        pkgs = tstpkg || return
        pkgs.each { |pkg|
            # we first set install to 'true', and make sure something gets
            # installed
            assert_nothing_raised {
                pkg = Puppet.type(:package).create(:name => pkg, :install => true)
            }
            assert_nothing_raised {
                pkg.retrieve
            }

            if pkg.insync?
                Puppet.notice "Test package %s is already installed; please choose a different package for testing" % pkg
                next
            end

            comp = newcomp("package", pkg)

            assert_events([:package_installed], comp, "package")

            # then uninstall it
            assert_nothing_raised {
                pkg[:install] = false
            }


            pkg.retrieve

            assert(! pkg.insync?, "Package is insync")

            assert_events([:package_removed], comp, "package")

            # and now set install to 'latest' and verify it installs
            # FIXME this isn't really a very good test -- we should install
            # a low version, and then upgrade using this.  But, eh.
            assert_nothing_raised {
                pkg[:install] = "latest"
            }

            assert_events([:package_installed], comp, "package")

            pkg.retrieve
            assert(pkg.insync?, "After install, package is not insync")

            assert_nothing_raised {
                pkg[:install] = false
            }


            pkg.retrieve

            assert(! pkg.insync?, "Package is insync")

            assert_events([:package_removed], comp, "package")
        }
    end
    end
end
end

# $Id$
