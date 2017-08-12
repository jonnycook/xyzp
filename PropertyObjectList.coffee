define ['xyzp/XObject', 'xyzp/util', 'xyzp/XArray', 'xyzp/ObservePool'], (XObject, util, XArray, ObservePool) ->
	class PropertyObjectList extends XObject
		constructor: (@source, @propertyName) ->
			super
			@array = @addObject new XArray
			@observePool = @addObject new ObservePool
			@update()
			@observeObject @source, '_doUpdate'
			@array.on 'observeRetain', => @retain()
			@array.on 'observeRelease', => @release()

		_doUpdate: ->
			if !@_willUpdate
				@_willUpdate = true
				setTimeout (=>@update(); @_willUpdate = false), 0



		update: ->
			@array.clear()
			@observePool.allStopObserving()
			@source.each (object) =>
				@observePool.observe object.prop(@propertyName), (=>@_doUpdate())
				@array.push object.get @propertyName

	util.observableProxy PropertyObjectList, 'array'
	util.arrayProxy PropertyObjectList, 'array'

	PropertyObjectList