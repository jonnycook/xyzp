define ['xyzp/Observable', 'xyzp/XObject'], (Observable, XObject) ->
	class XValue extends XObject
		__valueContainer: true
		constructor: (@_value)->
			super

		set: (value) ->
			if @_value != value
				oldValue = @_value
				@_value = value
				@_fireMutation type:'set', value:value, prevValue:oldValue

		get: ->
			xyz.ValueCapture.capture @
			@_value

		value: -> @get()

		form: -> @

		meta: (query) -> @_meta?[query]

	_.extend XValue::, Observable::

	XValue