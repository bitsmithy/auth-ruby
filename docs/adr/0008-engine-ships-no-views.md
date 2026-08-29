# The Rails Engine ships no branded views

Authentication screens must match each Host Application's navigation, copy, visual system, accessibility behavior, and legal guidance.

The RubyAuth Rails Engine renders named Host Application templates and ships an install generator with accessible starter templates rather than treating those templates as the library's production interface.
RubyAuth owns route and form contracts, safe failures, and authentication orchestration; the Host Application owns every rendered decision and can replace generated files immediately.
