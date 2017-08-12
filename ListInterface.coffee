define ['xyzp/XObject'], (XObject) ->
	class ListInterface extends XObject
		@id: 1
		setDataSource: (dataSource) ->
			if dataSource?.observe
				@dataSource?.stopObserving @_observer
				@set dataSource
				@dataSource = dataSource
				dataSource.observe @_observer = (mutation) =>
					switch mutation.type
						when 'insertion'
							@insert mutation.value, mutation.position
						when 'deletion'
							@delete mutation.position
						when 'movement'
							@move mutation.from, mutation.to
						when 'setArray'
							@set @dataSource
						when 'reset'
							@set @dataSource

			else
				@set dataSource
				@dataSource = dataSource


		_dataSourceLength: ->
			if _.isArray @dataSource
				@dataSource.length
			else
				@dataSource.length()
					
		destruct: ->
			if @dataSource?.observe
				@dataSource?.stopObserving @_observer

			super

		constructor: (@el, selector, @mapping) ->
			super
			@id = ListInterface.id++
			if _.isString selector
				@template = $ el.find(selector).get 0
			else
				@template = selector
			# @template = $ @template.get 0

			if @template.length == 0
				#Debug.log view
				throw new Error "Failed to find template '#{selector}'"
			
			@prevSibling = @template.prev()
			@nextSibling = @template.next()
			@parent = @template.parent()

			if @parent.length == 0
				#Debug.log view
				throw new Error "BAD"			
			@els = []
			@deleteCbs = []

			@template.detach()

			
		get: (position) -> @els[position]?.el
		
		clear: ->
			(el.el.remove(); el.onDelete()) for el in @els
			@els = []
			@onLengthChanged?()
		
		set: (data) ->
			@clear()
			data.forEach (item, i) =>
				@insert item, i, false
			@onMutation?()
						
		delete: (i) ->
			el = @els[i]
			@els.splice i, 1
		
			if @onDelete
				@onDelete el.el, -> el.el.remove()
			else
				el.el.remove()

			el.onDelete()

			if @count && @fromEnd && @els.length
				start = Math.max 0, @_dataSourceLength() - @count
				if i >= start
					@els[start].el.show()

			@onLengthChanged?()
			@onMutation?()

		insert: (data, pos, signalMutation=true) ->
			deleteCb = null
			# view = null
			el = @mapping @template.clone(), data,
				pos:pos
				onDelete: (cb) -> deleteCb = cb
				# view: =>
				# 	view ?= @view.createView()
				# 	view
				# delete: =>
				# 	@dataSource.sendDeleteMessage @dataSource.indexOf(data)

			elEntry =
				data:data
				el:el
				onDelete: ->
					deleteCb?()
					# view.destruct() if view

			next = @els[pos]?.el
			if next
				# @parent.get(0).insertBefore el.get(0), next.get(0)
				if next.get 0
					next.before el
				else
					parent.append el
			else
				# @parent.get(0).insertBefore el.get(0), @nextSibling.get(0)
				if @nextSibling.get(0)
					@nextSibling.before el
				else
					@parent.append el

			
			if pos == 0
				@els.unshift elEntry
			else if pos == @els.length
				@els.push elEntry
			else
				@els.splice pos, 0, elEntry

			if @count && @fromEnd
				start = @_dataSourceLength() - @count
				if pos < start
					el.hide()
				else
					if @els[start - 1]
						@els[start - 1].el.hide()

			@onInsert? el
			@onLengthChanged?()

			@onMutation?() if signalMutation
					
		push: (data) ->
			@insert data, @els.length
			
		move: (from, to) ->
			el = @els[from].el
			if from > to
				el.detach().insertBefore(@els[to].el)
			else
				el.detach().insertAfter(@els[to].el)

			[elEntry] = @els.splice from, 1
			@els.splice to, 0, elEntry
			
			@onMove? from, to
			@onMutation?()
			
		length: -> @els.length
