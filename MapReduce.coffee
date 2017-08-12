define ['xyzp/XObject', 'xyzp/MappedArray', 'xyzp/ReducedArray', 'xyzp/util'], (XObject, MappedArray, ReducedArray, util) ->
	class MapReduce extends XObject
		constructor: (@source, mapFunc, reduceFuncs...) ->
			super
			@mappedArray = new MappedArray @source, mapFunc
			@reducedArray = new ReducedArray @mappedArray, reduceFuncs...
			@reducedArray.on 'observeRetain', => @retain()
			@reducedArray.on 'observeRelease', => @release()

	util.observableProxy MapReduce, 'reducedArray'
	util.arrayProxy MapReduce, 'reducedArray'

	MapReduce
