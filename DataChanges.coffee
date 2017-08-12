define ->
	class DataChanges
		constructor: (@_cb) ->
			@_changes = {}
			@_enabled = true

		disable: ->
			@_enabled = false

		enable: ->
			@_enabled = true


		createInstance: (level, model, id, values) ->
			return if not @_enabled
			for i in [0..level]
				@_changes[i] ?= {}
				@_changes[i][model] ?= {}
				@_changes[i][model][id] = values
			@_callCb()

		deleteInstance: (level, model, id) ->
			return if not @_enabled
			for i in [0..level]
				@_changes[i] ?= {}
				@_changes[i][model] ?= {}
				@_changes[i][model][id] = 'delete'
			@_callCb()

		setInstanceProperty: (level, model, id, attrName, value) ->
			return if not @_enabled
			for i in [0..level]
				@_changes[i] ?= {}
				@_changes[i][model] ?= {}
				@_changes[i][model][id] ?= {}
				@_changes[i][model][id][attrName] = value
			@_callCb()

		addToInstanceRelationship: (level, model, id, relName, instanceId) ->
			return if not @_enabled
			for i in [0..level]
				@_changes[i] ?= {}
				@_changes[i][model] ?= {}
				@_changes[i][model][id] ?= {}
				if dataManager.isTemporaryId id
					@_changes[i][model][id][relName] ?= []
					@_changes[i][model][id][relName].push instanceId
				else
					if @_changes[i][model][id][relName + '(add)']
						@_changes[i][model][id][relName + '(add)'].push instanceId
					else
						@_changes[i][model][id][relName + '(add)'] = ['add', instanceId]
			@_callCb()

		removeFromInstanceRelationship: (level, model, id, relName, instanceId) ->
			return if not @_enabled
			for i in [0..level]
				@_changes[i] ?= {}
				@_changes[i][model] ?= {}
				@_changes[i][model][id] ?= {}
				if @_changes[i][model][id][relName + '(remove)']
					@_changes[i][model][id][relName + '(remove)'].push instanceId
				else
					@_changes[i][model][id][relName + '(remove)'] = ['remove', instanceId]
			@_callCb()

		_callCb: ->
			if !@_waiting
				clearTimeout @_timerId
				done = =>
					delete @_waiting
					if @_newChanges
						delete @_newChanges
						@_callCb()

				@_timerId = setTimeout (=>
					@_waiting = true
					@_cb @_changes, done
				), 0
			else
				@_newChanges = true

		clear: ->
			@_changes = {}
