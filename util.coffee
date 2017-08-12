define ->
	util =
		observableProxy: (klass, observableMemberName) ->
			_.extend klass::,
				observe: (observer) -> @[observableMemberName].observe observer
				stopObserving: (observer) -> @[observableMemberName].stopObserving observer

		arrayProxy: (klass, memberName) ->
			_.extend klass::,
				__list:true
				forEach: (iter) -> @[memberName].forEach iter
				each: (iter) ->
					xyz.ValueCapture.capture @, =>
						@[memberName].each iter
				length: -> 
					xyz.ValueCapture.capture @, =>
						@[memberName].length()
				contains: (value) -> @[memberName].contains value
				value: -> @


			klass::get ?= (i) -> @[memberName].get i
			klass::derive ?= (value, params...) -> @[memberName].derive value, params...


		objectList: (array) ->
			array.oldDerive = array.derive
			array.derive = (name, params...) ->
				if util.objectList.derivations[name]
					util.objectList.derivations[name] array, params...
				else
					@oldDerive name, params...
			array

		isScalar: (obj) ->
			_.isNumber(obj) || _.isString(obj)

		isValueContainer: (obj) ->
			obj.__valueContainer

		isList: (obj) ->
			obj.__list

		compare: (a, b, order='asc') ->
			if a instanceof Date
				a = a.getTime() if a
				b = b.getTime() if b

			if a < b
				if order == 'asc'
					-1
				else if order == 'desc'
					1
			else if a > b
				if order == 'asc'
					1
				else if order == 'desc'
					-1
			else
				0

		type: (value) ->
			if util.isValueContainer value
				value.meta 'type'
			else if _.isString value
				'string'
			else if _.isNumber value
				if value % 1 == 0
					'int'
				else
					'float'
