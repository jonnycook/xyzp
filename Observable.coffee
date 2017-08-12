define ->
	class Observable
		observe: (observer) ->
			# if @destructed
				# throw new Error 'destructed'
			if !observer
				throw new Error()
			@_observers ?= []
			@_observers.push observer

			if @retain && @_observers.length == 1
				if @_observeReleaseTimer
					clearTimeout @_observeReleaseTimer
					delete @_observeReleaseTimer
				@retain()
				@fireEvent 'observeRetain'
				@_observeRetained = true


		stopObserving: (observer) ->
			before = @_observers.length
			@_observers ?= []
			_.pull @_observers, observer

			if before && !@_observers.length && @retain
				@_observeReleaseTimer = setTimeout (=>
					@release()
					@fireEvent 'observeRelease'
					@_observeRetained = false
				), 0


		_fireMutation: (mutation) ->
				mutation.observable = @
			# setTimeout (=>
				if xyz.MutationEvents.isPaused()
					xyz.MutationEvents.addMutation @, mutation
				else
					if @_observers
						for observer, i in _.clone @_observers
							observer? mutation, i
			# ), 0
