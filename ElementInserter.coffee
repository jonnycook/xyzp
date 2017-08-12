define ->
	class ElementInserter
		constructor: (@el, @anchor) ->

		insert: (el) ->
			switch @anchor
				when 'first'
					@el.prepend el
				when 'last'
					@el.append el
				when 'before'
					@el.before el
				when 'after'
					@el.after el