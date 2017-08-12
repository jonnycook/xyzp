define ['xyzp/util', 'xyzp/XObject'], (util, XObject) ->
	class ValueInterface extends XObject
		constructor: (@el, @func, @opts={}) ->
			super
			if _.isString @func
				switch @func
					when 'html'
						@func = (el, value) -> el.html value

					when 'value'
						@func = (el, value) ->
							el.val value

					when 'checked'
						@func = (el, value) ->
							el.prop 'checked', value

					when 'attr'
						@func = (el, value) =>
							el.attr @opts.attr, value

		set: (value, mapping=true) ->
			if @form
				@stopObserving @form
				delete @form

			@el.data 'boundValue', value

			if value && value.form
				@form = value.form 'display'
				@observeObject @form, => @func @el, @opts.mapping @form.get()
				@func @el, @opts.mapping @form.get()
			else
				if @opts.mapping && mapping
					value = @opts.mapping value

				@func @el, value

		destruct: ->
			super
			@set null, false
			@el.removeData 'boundValue'
			if util.isValueContainer @dataSource
				@dataSource.stopObserving @observer

		setDataSource: (@dataSource) ->
			if util.isScalar dataSource
				@set dataSource
			else
				
				if util.isValueContainer @dataSource
					@set @dataSource.get()
					@observer = =>
						# console.log @dataSource.get()
						@set @dataSource.get()
					@dataSource.observe @observer
				else
					@set @dataSource

