# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2011/01/17
# Description:	This file contains the base class for lexers that use RLTK.

############
# Requires #
############

# Standard Library
require 'strscan'

# Ruby Language Toolkit
require 'rltk/token'

#######################
# Classes and Modules #
#######################

module RLTK # :nodoc:
	
	# A LexingError exception is raised when an input stream contains a
	# substring that isn't matched by any of a lexer's rules.
	class LexingError < StandardError
		
		# @param [Integer]	stream_offset	Offset from begnning of string.
		# @param [Integer]	line_number	Number of newlines encountered so far.
		# @param [Integer]	line_offset	Offset from beginning of line.
		# @param [String]	remainder		Rest of the string that couldn't be lexed.
		def initialize(stream_offset, line_number, line_offset, remainder)
			@stream_offset	= stream_offset
			@line_number	= line_number
			@line_offset	= line_offset
			@remainder	= remainder
		end
		
		# @return [String] String representation of the error.
		def to_s
			"#{super()}: #{@remainder}"
		end
	end
	
	# The Lexer class may be sub-classed to produce new lexers.  These lexers
	# have a lot of features, and are described in the main documentation.
	class Lexer
		
		# @return [Environment] Environment used by an instantiated lexer.
		attr_reader :env
		
		#################
		# Class Methods #
		#################
		
		class << self
			# @return [Symbol] State in which the lexer starts.
			attr_reader :start_state
			
			# Installs instance class varialbes into a class.
			#
			# @return [void]
			def install_icvars
				@match_type	= :longest
				@rules		= Hash.new {|h,k| h[k] = Array.new}
				@start_state	= :default
			end
			
			# Called when the Lexer class is sub-classed, it installes
			# necessary instance class variables.
			#
			# @return [void]
			def inherited(klass)
				klass.install_icvars
			end
		
			# Lex *string*, using *env* as the environment.  This method will
			# return the array of tokens generated by the lexer with a token
			# of type EOS (End of Stream) appended to the end.
			#
			# @param [String]		string	String to be lexed.
			# @param [String]		file_name	File name used for recording token positions.
			# @param [Environment]	env		Lexing environment.
			#
			# @return [Array<Token>]
			def lex(string, file_name = nil, env = self::Environment.new(@start_state))
				# Offset from start of stream.
				stream_offset = 0
		
				# Offset from the start of the line.
				line_offset = 0
				line_number = 1
			
				# Empty token list.
				tokens = Array.new
			
				# The scanner.
				scanner = StringScanner.new(string)
			
				# Start scanning the input string.
				until scanner.eos?
					match = nil
				
					# If the match_type is set to :longest all of the
					# rules for the current state need to be scanned
					# and the longest match returned.  If the
					# match_type is :first, we only need to scan until
					# we find a match.
					@rules[env.state].each do |rule|
						if (rule.flags - env.flags).empty?
							if txt = scanner.check(rule.pattern)
								if not match or match.first.length < txt.length
									match = [txt, rule]
								
									break if @match_type == :first
								end
							end
						end
					end
				
					if match
						rule = match.last
					
						txt = scanner.scan(rule.pattern)
						type, value = env.rule_exec(rule.pattern.match(txt), txt, &rule.action)
					
						if type
							pos = StreamPosition.new(stream_offset, line_number, line_offset, txt.length, file_name)
							tokens << Token.new(type, value, pos) 
						end
					
						# Advance our stat counters.
						stream_offset += txt.length
					
						if (newlines = txt.count("\n")) > 0
							line_number += newlines
							line_offset  = 0
						else
							line_offset += txt.length()
						end
					else
						error = LexingError.new(stream_offset, line_number, line_offset, scanner.post_match)
						raise(error, 'Unable to match string with any of the given rules')
					end
				end
			
				return tokens << Token.new(:EOS)
			end
			
			# A wrapper function that calls {Lexer.lex} on the contents of a
			# file.
			#
			# @param [String]		file_name	File to be lexed.
			# @param [Environment]	env		Lexing environment.
			#
			# @return [Array<Token>]
			def lex_file(file_name, env = self::Environment.new(@start_state))
				File.open(file_name, 'r') { |f| self.lex(f.read, file_name, env) }
			end
			
			# Used to tell a lexer to use the first match found instead
			# of the longest match found.
			#
			# @return [void]
			def match_first
				@match_type = :first
			end
			
			# This method is used to define a new lexing rule.  The
			# first argument is the regular expression used to match
			# substrings of the input.  The second argument is the state
			# to which the rule belongs.  Flags that need to be set for
			# the rule to be considered are specified by the third
			# argument.  The last argument is a block that returns a
			# type and value to be used in constructing a Token. If no
			# block is specified the matched substring will be
			# discarded and lexing will continue.
			#
			# @param [Regexp, String]	pattern	Pattern for matching text.
			# @param [Symbol]			state	State in which this rule is active.
			# @param [Array<Symbol>]		flags	Flags which must be set for rule to be active.
			# @param [Proc]			action	Proc object that produces Tokens.
			#
			# @return [void]
			def rule(pattern, state = :default, flags = [], &action)
				# If no action is given we will set it to an empty
				# action.
				action ||= Proc.new() {}
				
				pattern = Regexp.new(pattern) if pattern.is_a?(String)
				
				r = Rule.new(pattern, action, state, flags)
				
				if state == :ALL then @rules.each_key { |k| @rules[k] << r } else @rules[state] << r end
			end
			alias :r :rule
			
			# Changes the starting state of the lexer.
			#
			# @param [Symbol] state Starting state for this lexer.
			#
			# @return [void]
			def start(state)
				@start_state = state
			end
		end
		
		####################
		# Instance Methods #
		####################
		
		# Instantiates a new lexer and creates an environment to be
		# used for subsequent calls.
		def initialize
			@env = self.class::Environment.new(self.class.start_state)
		end
		
		# Lexes a string using the encapsulated environment.
		#
		# @param [String] string		String to be lexed.
		# @param [String] file_name	File name used for Token positions.
		#
		# @return [Array<Token>]
		def lex(string, file_name = nil)
			self.class.lex(string, file_name, @env)
		end
		
		# Lexes a file using the encapsulated environment.
		#
		# @param [String] file_name File to be lexed.
		#
		# @return [Array<Token>]
		def lex_file(file_name)
			self.class.lex_file(file_name, @env)
		end
		
		# All actions passed to LexerCore.rule are evaluated inside an
		# instance of the Environment class or its subclass (which must have
		# the same name).  This class provides functions for manipulating
		# lexer state and flags.
		class Environment
			
			# @return [Array<Symbol>] Flags currently set in this environment.
			attr_reader :flags
			
			# @return [Match] Match object generated by a rule's regular expression.
			attr_accessor :match
			
			# Instantiates a new Environment object.
			#
			# @param [Symbol]	start_state	Lexer's start state.
			# @param [Match]	match		Match object for matching text.
			def initialize(start_state, match = nil)
				@state	= [start_state]
				@match	= match
				@flags	= Array.new
			end
			
			# This function will instance_exec a block for a rule after
			# setting the match value.
			#
			# @param [Match]	match	Match object for matching text.
			# @param [String]	txt		Text of matching string.
			# @param [Proc]	block	Block for matched rule.
			def rule_exec(match, txt, &block)
				self.match = match
				
				self.instance_exec(txt, &block)
			end
			
			# Pops a state from the state stack.
			#
			# @return [void]
			def pop_state
				@state.pop
				
				nil
			end
			
			# Pushes a new state onto the state stack.
			#
			# @return [void]
			def push_state(state)
				@state << state
				
				nil
			end
			
			# Sets the value on the top of the state stack.
			#
			# @param [Symbol] state New state for the lexing environment.
			#
			# @return [void]
			def set_state(state)
				@state[-1] = state
				
				nil
			end
			
			# @return [Symbol] Current state of the lexing environment.
			def state
				@state.last
			end
			
			# Sets a flag in the current environment.
			#
			# @param [Symbol] flag Flag to set as enabled.
			#
			# @return [void]
			def set_flag(flag)
				if not @flags.include?(flag)
					@flags << flag
				end
				
				nil
			end
			
			# Unsets a flag in the current environment.
			#
			# @param [Symbol] flag Flag to unset.
			#
			# @return [void]
			def unset_flag(flag)
				@flags.delete(flag)
				
				nil
			end
			
			# Unsets all flags in the current environment.
			#
			# @return [void]
			def clear_flags
				@flags = Array.new
				
				nil
			end
		end
		
		# The Rule class is used simply for data encapsulation.
		class Rule
			# @return [Proc] Token producting action to be taken when this rule is matched.
			attr_reader :action
			
			# @return [Regexp] Regular expression for matching this rule.
			attr_reader :pattern
			
			# @return [Array<Symbol>] Flags currently set in this lexing environment.
			attr_reader :flags
			
			# Instantiates a new Rule object.
			#
			# @param [Regexp]		pattern	Regular expression used to match to this rule.
			# @param [Proc]		action	Token producing action associated with this rule.
			# @param [Symbol]		state	State in which this rule is active.
			# @param [Array<Symbol>]	flags	Flags that must be enabled for this rule to match.
			def initialize(pattern, action, state, flags)
				@pattern	= pattern
				@action	= action
				@state	= state
				@flags	= flags
			end
		end
	end
end
