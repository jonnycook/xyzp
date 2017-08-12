define ['xyzp/XObject', 'xyzp/util', 'xyzp/XArray', 'xyzp/ObservePool'], (XObject, util, XArray, ObservePool) ->
	class UniqueObjectList extends XObject
		constructor: (@source) ->
			super
			@array = new XArray
			@update()
			@observeObject @source, '_doUpdate'
			@array.on 'observeRetain', => @retain()
			@array.on 'observeRelease', => @release()


		_doUpdate: ->
			if !@_willUpdate
				@_willUpdate = true
				setTimeout (=>
					@update()
					@_willUpdate = false
				), 0


		update: ->
			@array.clear()
			@source.each (object) =>
				if !@array.contains object
					@array.push object



	util.observableProxy UniqueObjectList, 'array'
	util.arrayProxy UniqueObjectList, 'array'


	UniqueObjectList