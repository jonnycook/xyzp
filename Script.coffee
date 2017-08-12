define ['xyzp/XValue', 'xyzp/ListInterface', 'xyzp/ValueInterface', 'xyzp/PropertyPath', 'xyzp/ComputedValue', 'xyzp/util', 'xyzp/HasManyRelationship', 'xyzp/XArray', 'xyzp/ComputedList', 'xyzp/Model'], (XValue, ListInterface, ValueInterface, PropertyPath, ComputedValue, util, HasManyRelationship, XArray, ComputedList, Model) ->
	class Token
		constructor: (@type, @value) ->


	class TokenStream
		constructor: (@tokens) ->
			@i = 0

		hasNext: -> @i < @tokens.length

		next: (type=null, values...) ->
			if type
				if !@checkToken type, values...
					throw new Error 'invalid token'

			@tokens[@i++]

		nextValue: (type=null, values...) ->
			@next(type, values...).value

		check: (types...) ->
			@hasNext() && @tokens[@i].type in types

		checkToken: (type, values...) ->
			type = [type] if !_.isArray type
			@hasNext() && @tokens[@i].type in type && (!values.length || @tokens[@i].value in values)

	window.tokenize = (input) ->
		tokenTypes = 
			number:/\d(\.\d+)?/
			# arrow: '->'
			sigil: '->|//|[@#:$%.&^]'
			string: /'(?:\\'|[^'])*'|"(?:\\"|[^"])*"/
			operator: '<=|>=|!=|==|&&|\\|\\||[!+\\-=*/<>]'
			parenthesis: '[()]'
			comma: ','
			identifier: /[A-z][A-z0-9]*/

		tokenMappings =
			string: (value) ->
				value.substring(1, value.length - 1).replace(/\\/g, '\\').replace(/\'/g, '\'').replace(/\"/g, '"')

		pattern = for tokenType, tokenPattern of tokenTypes
			'(?:' + (if tokenPattern instanceof RegExp then tokenPattern.source else tokenPattern) + ')'

		pattern = pattern.join '|'
		pattern = new RegExp pattern, 'g'

		tokenMatches = input.match pattern

		tokens = []
		for tokenMatch in tokenMatches
			for tokenType, tokenPattern of tokenTypes
				if new RegExp("^#{new RegExp(tokenPattern).source}$").exec tokenMatch
					tokens.push new Token tokenType, tokenMappings[tokenType]?(tokenMatch) ? tokenMatch
					break

		tokens

	class ParseNode
		constructor: (@type, @contents) ->

		@fromToken: (nodeFactory, token) ->
			nodeFactory.createNode ParseNode, token.type, token.value

	class PathComponent
		constructor: (@identifier, @type, @params) ->

	parsePathComponent = (nodeFactory, stream, i, config={}) ->
		if i == 0
			if stream.check 'sigil'
				new PathComponent stream.nextValue('sigil', config.baseSigils...), 'base'
			else
				identifier = stream.nextValue(['identifier', 'number'])
				if stream.checkToken 'parenthesis', '('
					stream.next()
					params = []
					while param = parseExpression nodeFactory, stream, config
						params.push param
						if stream.check 'comma'
							stream.next()
						else if stream.check 'parenthesis', ')'
							break

					stream.next 'parenthesis', ')'

					new PathComponent identifier, 'method', params
				else
					new PathComponent identifier, 'prop'

		else
			if stream.checkToken 'sigil', '.', ':', '->'			
				sigil = stream.nextValue 'sigil', '.', ':', '->'
				identifier = stream.nextValue ['identifier', 'number']
				if sigil in ['.', ':']
					if stream.checkToken 'parenthesis', '('
						stream.next()
						params = []
						while param = parseExpression nodeFactory, stream, config
							params.push param
							if stream.check 'comma'
								stream.next()
							else if stream.check 'parenthesis', ')'
								break

						stream.next 'parenthesis', ')'

						if sigil == '.'
							new PathComponent identifier, 'method', params
						else if sigil == ':'
							new PathComponent identifier, 'transform', params
					else
						if sigil == '.'
							new PathComponent identifier, 'prop'
						else if sigil == ':'
							new PathComponent identifier, 'transform'
				else
					new PathComponent identifier, 'metaQuery'
			else if i == 1 && stream.check 'identifier'
				identifier = stream.nextValue(['identifier', 'number'])
				if stream.checkToken 'parenthesis', '('
					stream.next()
					params = []
					while param = parseExpression nodeFactory, stream, config
						params.push param
						if stream.check 'comma'
							stream.next()
						else if stream.check 'parenthesis', ')'
							break

					stream.next 'parenthesis', ')'

					new PathComponent identifier, 'method', params
				else
					new PathComponent identifier, 'prop'

	parsePath = (nodeFactory, stream, config={}) ->
		components = []
		i = 0
		loop
			component = parsePathComponent nodeFactory, stream, i++, config
			if component
				components.push component
			else
				return nodeFactory.createNode ParseNode, 'path', components


	parseExpression = (nodeFactory, stream, config={}) ->
		output = []
		while stream.hasNext()
			if stream.check 'number', 'string', 'operator'
				output.push ParseNode.fromToken nodeFactory, stream.next()
			else if stream.check 'sigil', 'identifier'
				output.push parsePath nodeFactory, stream, config
			else
				break

		if output.length
			nodeFactory.createNode ParseNode, 'expression', output

	nodeInterpreters = 
		expression: (node) ->
			@interpretNode node.contents[0]
			# (compileNode(n) for n in node.contents).join ''

		path: (node) -> @_executePath node.contents

		number: (node) -> parseFloat node.contents

		string: (node) -> node.contents

		operator: (node) -> node.contents

	class Script
		createNode: (constr, args...) ->
			n = new constr args...
			n.debug = @debug
			n

		interpretNode: (node) ->
			nodeInterpreters[node.type].call @, node

		constructor: (@src, params, @debug) ->
			{bases:@bases, scope:@scope, value:@_value, valueCont:@_valueCont, operation:@operation, defaultParams:@defaultParams} = params
			@node = parseExpression @, new TokenStream(tokenize src), baseSigils:_.keys @bases

		execute: -> 
			@interpretNode @node

		_executePath: (path, returnEndPair=false, returnCont=false) ->
			if @debug
				console.log path

			delete @valueContainer
			currentObject = null
			for comp, i in path
				if @debug
					console.log currentObject
				if (returnEndPair || returnCont) && i == path.length - 1
					if returnEndPair
						return [currentObject, comp]
					else if returnCont
						return @_valueCont currentObject, comp.identifier
				else
					switch comp.type
						when 'base'
							currentObject = @bases[comp.identifier]

						when 'prop'
							obj = if i == 0 then @scope[0] else currentObject

							console.log 'asdf', obj if @debug

							if @operation == 'call' && i == path.length - 1 && !@params
								params = @defaultParams ? []

								if obj.hasMethod? comp.identifier
									currentObject = obj.call comp.identifier, params...
								else if _.isFunction obj[comp.identifier]
									currentObject = obj[comp.identifier].apply obj, params
							else
								@valueContainer = @_valueCont obj, comp.identifier

								currentObject = @_value obj, comp.identifier
								if !currentObject?
									return

							if _.isFunction currentObject
								currentObject = currentObject()

						when 'transform'
							params = if comp.params then for param in comp.params
								@interpretNode param
							else []
							if currentObject.derive
								currentObject = currentObject.derive comp.identifier, params...
							else
								@valueContainer = @valueContainer.derive comp.identifier, params...
								currentObject = @valueContainer.get()

						when 'method'
							@params = true
							obj = if i == 0 then @scope[0] else currentObject
							params = if comp.params then for param in comp.params
								@interpretNode param
							else []
							@params = false

							if obj.hasMethod?(comp.identifier)
								currentObject = obj.call comp.identifier, params...
							else if _.isFunction obj[comp.identifier]
								currentObject = obj[comp.identifier].apply obj, params
							else
								throw new Error()

							if @operation != 'call'
								@valueContainer = @_valueCont obj, comp.identifier, params


						when 'metaQuery'
							currentObject = @valueContainer.meta comp.identifier

			currentObject


