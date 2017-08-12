define ['xyzp/XObject', 'xyzp/util', 'xyzp/XArray', 'xyzp/ObservePool', 'xyzp/XValue'], (XObject, util, XArray, ObservePool, XValue) ->
	class ObjectListAggregate extends XObject
		__valueContainer:
			readOnly:true

		constructor: (@source, @propertyName) ->
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
			@observePool.allStopObserving()
			sum = 0
			@source.each (object) =>
				@observePool.observe object.prop(@propertyName), (=>@_doUpdate())
				if _.isNumber(object.get @propertyName) && !_.isNaN(object.get @propertyName)
					sum += object.get @propertyName

			@value.set sum

		get: -> @value.get()

		value: -> @get()

		form: -> @

		meta: (query) -> @_meta?[query]

	util.observableProxy ObjectListAggregate, 'value'
	ObjectListAggregate