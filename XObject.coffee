define ->
	class XObject
		@isObject: (value) -> value && value.retain && value.release

		constructor: (autoRelease=true) ->
			@_retainCount = 1
			@autoRelease() if autoRelease
			# @_createdStack = new Error().stack

		on: (eventName, listener) ->
			@_eventListeners ?= {}
			@_eventListeners[eventName] ?= []
			@_eventListeners[eventName].push listener

		fireEvent: (name) ->
			if listeners = @_eventListeners?[name]
				listener() for listener in listeners

		observeObject: (observable, observer) ->
			if _.isString observer
				observerName = observer
				observer = (mutation) => @[observerName] mutation

			observable.observe observer
			@observers ?= []
			@observers.push observable:observable, observer:observer

			if @debug && window.debug
				console.log observable

		allStopObserving: ->
			if @debug
				console.log 'asdf', @
			if @observers
				observable.stopObserving observer for {observable:observable, observer:observer} in @observers
				delete @observers

		stopObserving: (observable, observer=null) ->
			if @observers
				toRemove = []
				for o, i in @observers
					if o.observable == observable && (observer == null || o.observer == observer)
						o.observable.stopObserving o.observer
						toRemove.push i
						if observer
							break

				for i in [toRemove.length...0]
					@observers.splice toRemove[i], 1

		destruct: ->
			@destructed = true
			# debugger
			@allStopObserving()
			object.release() for object in @objects if @objects
			@fireEvent 'destruct'
			# console.log 'destruct', @

		addObject: (object) ->
			if XObject.isObject object
				@objects ?= []
				@objects.push object
				object.retain()
				object

		removeObject: (object) ->
			if XObject.isObject(object) && @objects
				index = @objects.indexOf object
				if index != -1
					@objects.splice index, 1
					object.release()

		autoRelease: ->
			setTimeout (=>@release()), 1000
			@

		retain: ->
			if @destructTimer
				clearTimeout @destructTimer
				delete @destructTimer
			@_retained ?= []
			@fireEvent 'retain'
			@_retainCount ?= 1
			@_retainCount++
			# @_retained.push new Error().stack
			@

		release: ->
			if !@_retainCount || !--@_retainCount
				if 0
					clearTimeout @destructTimer
					@destructTimer = setTimeout (=>
						@destruct()
						delete @destructTimer
					), 0
				else
					@destruct()
			@