define ['xyzp/XObject', 'xyzp/XArray', 'xyzp/ObservePool', 'xyzp/util'], (XObject, XArray, ObservePool, util) ->
	class PagedList extends XObject
		constructor: (@source, @pageCount) ->
			super
			@pagesShown = 1
			@array = @addObject new XArray
			@update()
			@observeObject @source, '_doUpdate'
			@array.on 'observeRetain', => @retain()
			@array.on 'observeRelease', => @release()

		_doUpdate: (mutation) ->
			if !@_willUpdate
				@_willUpdate = true
				setTimeout (=>@update(); @_willUpdate = false), 0

		update: ->
			@array.clear()

			for i in [0...Math.min @source.length(), @pagesShown*@pageCount]
				@array.push @source.get(i)

		nextPage: ->
			maxPage = Math.ceil @source.length()/@pageCount
			@pagesShown = Math.min maxPage, @pagesShown + 1
			@_doUpdate()

		more: -> @nextPage()

		less: ->
			@pagesShown = Math.max 1, @pagesShown - 1
			@_doUpdate()


		get: (prop) ->
			if prop == 'totalLength'
				@source.length()
			else
				@array.get prop


	util.observableProxy PagedList, 'array'
	util.arrayProxy PagedList, 'array'

	PagedList
