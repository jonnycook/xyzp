define ['xyzp/XObject', 'xyzp/util', 'xyzp/XArray', 'xyzp/ObservePool', 'xyzp/XValue'], (XObject, util, XArray, ObservePool, XValue) ->
	class FormattedValue extends XObject
		__valueContainer:
			readOnly:true

		constructor: (@format, @source) ->
			super
			@value = @addObject new XValue
			@observePool = @addObject new ObservePool
			# TODO: fix hack
			setTimeout (=>@update()), 0
			@observeObject @source, '_doUpdate'
			@value.on 'observeRetain', => @retain()
			@value.on 'observeRelease', => @release()

		_doUpdate: ->
			if !@_willUpdate
				@_willUpdate = true
				setTimeout (=>@update(); @_willUpdate = false), 0

		update: ->
			if _.isFunction @format
				@value.set @format @source.get()
			else
				@value.set @format.replace(/([^%]|^)%([^%]|$)/g, (match, pre, post) -> pre + @source.get() + post)
						

		get: -> @value.get()

		value: -> @get()

		form: -> @

		meta: (query) -> @_meta?[query]

	util.observableProxy FormattedValue, 'value'
	FormattedValue