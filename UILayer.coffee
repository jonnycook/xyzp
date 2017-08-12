define ['xyzp/XValue', 'xyzp/ListInterface', 'xyzp/ValueInterface', 'xyzp/PropertyPath', 'xyzp/ComputedValue', 'xyzp/util', 'xyzp/HasManyRelationship', 'xyzp/XArray', 'xyzp/ComputedList', 'xyzp/Model', 'xyzp/Script'], (XValue, ListInterface, ValueInterface, PropertyPath, ComputedValue, util, HasManyRelationship, XArray, ComputedList, Model, Script) ->
	initsForBinding = (binding, inits) ->
		newInits = {}
		for key, value of inits
			if key == binding
				_.extend newInits, value
			else if key.startsWith "#{binding}."
				newInits[key.substr "#{binding}.".length] = value
		newInits


	class UILayer
		__type:'UILayer'
		constructor: (@name) ->
			# @stack = new Error().stack

		on: (eventName, listener) ->
			@_eventListeners ?= {}
			@_eventListeners[eventName] ?= []
			@_eventListeners[eventName].push listener

		fireEvent: (name) ->
			if listeners = @_eventListeners?[name]
				listener() for listener in listeners

		destruct: (removeFromParent=true) ->
			if @parent && removeFromParent
				@parent.removeLayer @

			if @frames
				frame.destruct() for frame in @frames

			if @objects
				obj.release() for obj in @objects

			if @layers
				while @layers.length
					layer = @layers.shift()
					if layer
						layer.destruct()

			if @observers
				observable.stopObserving observer for {observable:observable, observer:observer} in @observers

			if @destructFuncs
				func() for func in @destructFuncs

			@fireEvent 'destruct'


		instantiate: (klass, params...) ->
			obj = new klass param...
			@addObject obj
			obj

		addFrame: (frame) ->
			@frames ?= []
			@frames.push frame

		addObject: (object) ->
			object.retain()
			@objects ?= []
			@objects.push object
			object

		removeObject: (object) ->
			if _.contains @object, object
				_.pull @objects, object
				object.release()

		addLayerProvider: (name, func) ->
			@providers ?= {}
			@providers[name] = func


		provider: (name) ->
			@providers?[name] ? @parent?.provider? name


		addValue: ->

		value: (name, create=true) ->
			@values ?= {}
			if !@values[name]
				ancestorValue = @parent?.value? name, false
				if ancestorValue
					return ancestorValue
				else if create
					@values[name] = new XValue().retain()
			@values[name]

		list: (name) ->
			if !@values[name]
				@values[name] = new XArray().retain()
				@values[name].layer = @
			@values[name]

		_globalProp: (prop) ->
			if @globalScope
				if @globalScope[prop]
					@globalScope[prop]
				else if @parent
					@parent._globalProp prop
			else if @parent
				@parent._globalProp prop

		addElement: (el, name) ->
			@elements ?= {}
			@elements[name] = el

		addElementBinding: (elementName, valueName) ->
			el = @elements[elementName]
			value = @value valueName
			el.val value.get()
			value.observe -> el.val value.get() if el.val() != value.get()
			if el.attr('type') == 'text'
				el.keyup ->
					if value.get() != el.val()
						value.set el.val()
					true

		addLayer: (layer) ->
			@layers ?= []
			@layers.push layer
			layer.parent = @
			layer.debug = @debug

			if layer.name
				@layersByName ?= {}
				@layersByName[layer.name] = layer

			layer

		removeLayer: (layer) ->
			_.pull @layers, layer
			if layer.name
				delete @layersByName[layer.name]

		layer: (name) -> 
			if @layersByName[name]
				@layersByName[name]

		addValueFormatter: (valueFormatter) ->
			@valueFormatters ?= []
			@valueFormatters.push valueFormatter

		formatValue: (value, opts={}) -> 
			if @valueFormatters
				for valueFormatter in @valueFormatters
					formattedValue = valueFormatter value, opts
					if formattedValue?
						return formattedValue

			if @parent
				@parent.formatValue value, opts
			else
				value

		addTmpl: (id, html) ->
			@tmpls ?= {}
			@tmpls[id] = html

		new: (params) ->
			layer = @addLayer new UILayer params.type
			@provider(params.type) layer, params
			layer

		newLayers: (layers) ->
			for params in layers
				@new params

		addHtml: (el, html) ->
			newEl = $ html
			el.append newEl
			@addDestructFunc -> newEl.remove()
			newEl

		addClass: (el, className) ->
			el.addClass className
			@addDestructFunc -> el.removeClass className

		setProp: (el, name, value) ->
			prevValue = el.prop name
			el.prop name, value
			@addDestructFunc -> el.prop name, prevValue

		setAttr: (el, name, value) ->
			prevValue = el.attr name
			el.attr name, value
			@addDestructFunc -> el.attr name, prevValue

		setData: (el, name, value) ->
			prevValue = el.data name
			el.data name, value
			@addDestructFunc ->
				if prevValue == undefined
					el.removeData name
				else
					el.data name, prevValue


		setValue: (valueCont, value) ->
			prevValue = valueCont.get()
			valueCont.set value
			@addDestructFunc -> valueCont.set prevValue


		addCss: (el, css) ->
			prevValues = {}
			for attr, value of css
				if el.get(0).style[attr]
					prevValues[attr] = el.get(0).style[attr]
				else
					prevValues[attr] = ''
			el.css css

			@addDestructFunc -> el.css prevValues

		switch: (value, cases) ->
			if _.isString value
				value = @value value

			lastCase = -1
			layer = null

			update = =>
				for i in [0...cases.length/2]
					test = cases[i*2]
					if (if _.isFunction test then test value.get() else value.get() == test)
						if i != lastCase
							lastCase = i
							if layer
								layer.destruct()

							layer = @addLayer new UILayer
							layer.undoOnDestruct = true
							cases[i*2 + 1] layer
						return

				lastCase = -1
				if layer
					layer.destruct()
					layer = null

			update()
			@observe value, update

		addLayerValueBinding: (value, insert, cases) ->
			value = @value value
			lastCase = -1
			layer = null
			func = =>
				for caseFunc, i in cases
					layerName = caseFunc value.get()
					if layerName
						if lastCase != i
							if layer
								layer.remove()

							lastCase = i
							layer = @new type:layerName
							layer.name = layerName
							@addLayer layer
							layer.insert insert
						break
					else
						if lastCase == i
							layer.remove()
							layer = null
							lastCase = -1
			@observe value, func
			func()

		bindList: (dataSource, el, selector, iter) ->
			el.data('boundList', dataSource)
			listInterface = @addObject new ListInterface el, selector, (el, data, onDelete:onDelete, pos:pos) =>
				layer = @addLayer new UILayer
				onDelete =>
					layer.destruct()
				iter el, data, layer:layer, index:pos

			listInterface.setDataSource dataSource

		bindValue: (el, dataSource, binding='html', opts={}) ->
			if !opts.mapping
				opts.mapping = (value) =>
					@formatValue value, type:util.type dataSource

			# opts.undoOnDestruct ||= @undoOnDestruct

			if el.is 'select'
				binding = 'value'
				valueInterface = @addObject new ValueInterface el, binding, opts
				valueInterface.setDataSource dataSource
				@bindEvent el, 'change', ->
					if el.find(':selected').data('boundValue')?
						dataSource.set el.find(':selected').data('boundValue'), 'editing'
					else
						dataSource.set el.val(), 'editing'
			else if el.is('input') && binding == 'html'
				if el.attr('type') == 'text'
					binding = 'value'
					opts.mapping = (value) =>
						@formatValue value, context:'editing', type:util.type dataSource

					valueInterface = @addObject new ValueInterface el, binding, opts
					valueInterface.setDataSource dataSource
					@bindEvent el, 'keyup', ->
						if dataSource.get() != el.val()
							dataSource.set el.val()
						true
					@bindEvent el, 'change', ->
						if dataSource.get() != el.val()
							dataSource.set el.val()
				else if el.attr('type') == 'checkbox'
					binding = 'checked'
					delete opts.mapping
					valueInterface = @addObject new ValueInterface el, binding, opts
					valueInterface.setDataSource dataSource
					@bindEvent el, 'change', ->
						if dataSource.get() != el.prop 'checked'
							dataSource.set el.prop 'checked'
			else
				valueInterface = @addObject new ValueInterface el, binding, opts
				valueInterface.setDataSource dataSource



		addTemplate: (name, templateEl) ->
			@templates ?= {}
			@templates[name] = templateEl

		addController: (name, constructor) ->
			@controllers ?= {}
			@controllers[name] = constructor

		createController: (name, params=[]) ->
			if constructor = @controllers?[name]
				new constructor params...
			else if @parent
				@parent.createController name, params



		template: (name) ->
			if template = @templates?[name]
				template
			else if @parent
				@parent.template name


		@_scriptValue: (obj, prop) ->
			if obj.__type == 'UILayer'
				if util.isList obj.value(prop)
					obj.value(prop)
				else
					obj.value(prop).get()
			else if (obj instanceof HasManyRelationship) || (obj instanceof Model)
				if prop.match(/^\d*|length$/)
					obj.get prop
				else
					obj.scope prop
			else if _.isFunction obj.get
				obj.get prop
			else if _.isFunction obj.attr
				obj.attr prop
			else if _.isFunction obj.get
				obj.get prop
			else
				retObj = obj[prop]
				if retObj
					if util.isValueContainer retObj
						retObj.get()
					else
						retObj

		@_scriptValueCont: (obj, prop, params=[]) ->
			if obj.__type == 'UILayer'
				obj.value(prop)
			else if obj instanceof HasManyRelationship || obj instanceof Model
				if prop.match(/^\d*$/)
					new XValue obj.get prop
				else
					obj.scope prop
			else if _.isFunction obj.prop
				obj.prop prop
			else if _.isFunction obj.attrCont
				obj.attrCont prop
			else if _.isFunction obj.prop
				obj.prop prop, params...
			else if util.isList obj
				new XValue obj.get prop
			else
				retObj = obj[prop]
				if retObj
					if util.isValueContainer retObj
						retObj
					else
						new XValue retObj

		debugBind: (el, scope, inits, controller, bindings) ->
			@bind el, scope, inits, controller, bindings, true

		bind: (el, scope={}, inits={}, controller=null, bindings={}) ->
			# console.log el.get(0), el.attr('bind-debug'), el.data('bindVisited'), @, new Error().stack if @debug || el.attr('bind-debug')
			if el.is('tmpl')
				@addTmpl el.attr('id'), el.html()
				el.remove()
				return

			if el.attr('tmpl')?
				el.removeAttr 'tmpl'
				@addTmpl el.attr('id'), el[0].outerHTML
				el.remove()
				return

			return if el.data('bindVisited')
			@setData el, 'bindVisited', true
			if el.is 'template'
				if el.html()
					@addTemplate el.attr('name'), el
				else
					templEl = @template el.attr 'name'

					contEl = $('<div />').append templEl.html()
					for attr in templEl.get(0).attributes
						continue if attr.nodeName == 'name'
						contEl.attr attr.nodeName, attr.value

					@bind contEl, scope, inits, controller, bindings
					el.before contEl#.children()

				el.remove()	
				return

			if !_.isArray scope
				scope = [scope]

			if !el.data('skipIf') && ifCond = el.attr 'if'
				# console.log @debug, el
				console.log el if @debug
				data = scope[0]
				layer = @
				condValue = new ComputedValue => !!eval "#{ifCond}"
				insertionPoint = document.createComment "if #{ifCond}"
				el.before insertionPoint
				template = el.clone()
				addedLayer = null
				el.remove()
				$(insertionPoint).after document.createComment 'endif'
				update = =>
					if condValue.get()
						if !addedLayer
							addedLayer = @addLayer new UILayer
							addedLayer.values = @values
							el = template.clone()
							el.data('skipIf', true)
							$(insertionPoint).after el
							addedLayer.bind el, scope, inits, controller, bindings
					else if addedLayer
						el.remove()
						addedLayer.destruct()
						addedLayer = null

				@observe condValue, update

				update()

			else
				if controllerName = el.attr('bind-controller')
					controller = @createController controllerName, [scope, layer:@, el:el]

				scriptArgs =
					bases:
						'$': inits
						':': controller
						# '#': dataManager._models
						'%': @
						'@': scope[0]
						'&': _.extend {el:el}, bindings
						'//': 
							get: (prop) => 
								v = @_globalProp(prop)
								if util.isValueContainer v
									v.get()
								else
									v
							prop: (prop) => 
								v = @_globalProp(prop)
								if util.isValueContainer v
									v
								else
									new XValue(v).retain()

							hasMethod: (prop) =>
								_.isFunction @_globalProp(prop)
							call: (prop, args...) =>
								m = @_globalProp(prop)
								m args...

					scope: scope
					value:UILayer._scriptValue
					valueCont:UILayer._scriptValueCont
					defaultParams: [el, scope, layer:@]

				if dataManager?
					scriptArgs.bases['#'] = dataManager._models

			
				if bindInit = el.attr('bind-init')
					script = new Script bindInit, _.extend operation:'call', scriptArgs
					script.execute()

				bound = false

				if listBinding = el.attr 'bind-list'
					# try
						script = new Script listBinding, scriptArgs, el.attr('bind-list-debug')?
						do (script) =>
							list = @addObject new ComputedList -> script.execute()
							# list = @addObject new Path(pathArgs).list scope, listBinding
							nextInits = initsForBinding listBinding, inits
							bindEl = el.find('[bind]:first')
							binding = bindEl.attr 'bind'
							bindEl.removeAttr 'bind'
							@bindList list, el, bindEl, (el, data, layer:layer, index:index) ->
								layer.value('_index').set index
								nextScope = [data].concat(scope)
								nextInits.init? el, nextScope, layer:layer, index:index
								nextBindings = bindings
								if binding
									nextBindings = _.clone(bindings)
									nextBindings[binding] = data
								layer.bind el, nextScope, nextInits, controller, nextBindings
								el

							for childEl in el.children()
								@bind $(childEl), list, inits, controller, bindings


						bound = true
					# catch e
						# Raven.captureException e, 

				if valueBinding = el.attr 'bind-value'
					script = new Script valueBinding, scriptArgs
					do (script) =>
						value = @addObject new ComputedValue (cont) ->
							v = script.execute()
							cont script.valueContainer
							v

						@bindValue el, value
					bound = true

				if attrBinding = el.attr 'bind-attr'
					[__, attr, binding] = attrBinding.match /^([^ ]*) +(.*)$/
					script = new Script binding, scriptArgs
					do (script) =>
						value = @addObject new ComputedValue (cont) ->
							value = script.execute()
							cont script.valueContainer
							value


						@bindValue el, value, 'attr', attr:attr
					# bound = true

				if classBinding = el.attr 'bind-class'
					script = new Script classBinding, scriptArgs
					do (script) =>
						value = @addObject new ComputedValue (cont) ->
							value = script.execute()
							cont script.valueContainer
							value


						# @bindValue el, value, 'attr', attr:attr
						@withValue value, (value, prevValue:prevValue) ->
							el.removeClass prevValue
							el.addClass value
					# bound = true

				if classBinding = el.attr 'bind-class-cond'
					[__, className, binding] = classBinding.match /^([^ ]*) +(.*)$/

					script = new Script binding, scriptArgs
					do (script) =>
						value = @addObject new ComputedValue (cont) ->
							value = script.execute()
							cont script.valueContainer
							value


						# @bindValue el, value, 'attr', attr:attr
						@withValue value, (value, prevValue:prevValue) ->
							if value
								el.addClass className
							else
								el.removeClass className
					# bound = true

				if layerBinding = el.attr('bind-layer')
					matches = layerBinding.match /^(.*?)\((.*?)\)$/
					paramParts = matches[2].split /\s*,\s*/
					params = {}
					for paramPart in paramParts
						param = paramPart.split ':'
						script = new Script param[1], scriptArgs
						do (script, param) =>
							# console.log param[1]
							params[param[0]] = @addObject new ComputedValue (cont) ->
								value = script.execute()
								cont script.valueContainer
								value

					layerData = 
						type:matches[1]
						el:el

					_.extend layerData, params

					@new layerData
					bound = true

				if clickBinding = el.attr 'bind-click'
					scriptArgs = _.extend operation:'call', scriptArgs
						
					script = new Script clickBinding, scriptArgs
					do (script) =>
						@bindEvent el, 'click', => script.execute(); false
					bound = true

				el.data('layer', @)
				el.data('bindVisited', true)

				for childEl in el.children()
					@bind $(childEl), scope, inits, controller, bindings


		withValue: (value, func, opts={}) ->
			opts.format ?= true
			if opts.format
				func @formatValue(value.get()), {}
				@observe value, (m) => func @formatValue(value.get(), type:util.type value), prevValue:m.prevValue, type:util.type value
			else
				func value.get(), {}
				@observe value, (m) => func value.get(), prevValue:m.prevValue, type:util.type value

		observe: (observable, observer) ->
			@observers ?= []
			observable.observe observer
			@observers.push observable:observable, observer:observer


		addDestructFunc: (func) ->
			@destructFuncs ?= []
			@destructFuncs.push func



		bindEvent: (el, event, handler) ->
			$(el).bind event, handler
			@addDestructFunc -> $(el).unbind event, handler

		ifCondSeq: (inserter, seq) ->


		if: (condFunc, layerInit) ->
			value = new ComputedValue condFunc
			layer = null
			update = =>
				if value.get()
					if !layer
						layer = @addLayer new UILayer
						layerInit layer
				else if layer
					layer.destruct()
					layer = null

			@observe value, update
			update()
