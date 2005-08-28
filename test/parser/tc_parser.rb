if __FILE__ == $0
    $:.unshift '../../lib'
    $:.unshift '..'
    $puppetbase = "../.."
end

require 'puppet'
require 'puppet/parser/parser'
require 'test/unit'
require 'puppettest'

# $Id$

class TestParser < Test::Unit::TestCase
    # hmmm
    # this is complicated, because we store references to the created
    # objects in a central store
    def setup
        Puppet[:loglevel] = :debug if __FILE__ == $0
        Puppet[:parseonly] = true
        #@lexer = Puppet::Parser::Lexer.new()
        @parser = Puppet::Parser::Parser.new()
        @@tmpfiles = []
    end

    def teardown
        @@tmpfiles.each { |file|
            if FileTest.exist?(file)
                system("rm -rf %s" % file)
            end
        }
    end

    def test_each_file
        textfiles { |file|
            Puppet.debug("parsing %s" % file) if __FILE__ == $0
            assert_nothing_raised() {
                @parser.file = file
                @parser.parse
            }

            Puppet::Type.eachtype { |type|
                type.each { |obj|
                    assert(obj.file)
                    assert(obj.name)
                    assert(obj.line)
                }
            }
            Puppet::Type.allclear
        }
    end

    def test_failers
        failers { |file|
            Puppet.debug("parsing failer %s" % file) if __FILE__ == $0
            assert_raise(Puppet::ParseError) {
                @parser.file = file
                @parser.parse
            }
            Puppet::Type.allclear
        }
    end

    def test_zzarrayrvalues
        parser = Puppet::Parser::Parser.new()
        ret = nil
        assert_nothing_raised {
            parser.string = 'file { "/tmp/testing": mode => [755, 640] }'
        }

        assert_nothing_raised {
            ret = parser.parse
        }
    end
end
