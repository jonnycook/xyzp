define ->
	class CounterCall
		constructor: (@func, @count=0) ->

		inc: -> @count++
		call: ->
			@func() if !@count || !--@count

		end: ->
			if !@count
				@func()
