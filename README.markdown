*Under construction: we're in the process of extracting this from our toolshed
repository; please pardon the flaws.*

# Ruckus: A DOM-Inspired Ruby Smart Fuzzer

Ruckus is a:

### Fuzzer

A tool used in security testing to generate pathological inputs for 
target code. Two common use cases:

*	Generating malicious protocol messages to attack network
	software

*	Creating malicious files in specific file formats to feed
	to target programs

### Smart Fuzzer

I'm stealing [Mike Eddington's](http://peachfuzzer.com/) term; 
Smart Fuzzers distinguish themselves from "just plain fuzzers" 
by being aware of the data format they're being used to test. In
both Eddington's Peach Fuzzer and Ruckus, you accomplish that by
defining data models (structures) to describe protocols and file
formats.

### Ruby

Peach Fuzzer is written in Python. So is Sully, Pedram Amini's
fuzzer. SPIKE is written in C. Ruckus is Ruby's answer, and it
tries to play to Ruby's strengths:

*	It's much more DSL-y than Peach Fuzzer or Sully

*	Unlike XML-bound Peach Fuzzer, it's "configuration files"
	are code

*	You don't really need to know Ruby to write those files

Long term I'm hoping Ruckus bears the same relationship to Ruby as
Expect did to Tcl.

### DOM-Inspired

Ruckus seperates metadata and actual content, and structures packets
and file formats as trees of nodes, each with classes and (when desired)
DOM-style id's (we call them "tags"). Ruckus data can be manipulated 
with tree traversal and "mutated" with cascading style sheet selector-type
logic.

