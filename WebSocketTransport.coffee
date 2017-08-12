define ->
		class WebSocketTransport
			constructor: (@server) ->
				@messageCbs = {}
				@messageNumber = 0

				@queue = []

				@version = 1

			init: (version, clientId, dbName, schemaVersion, cb) ->
				@ws = new WebSocket @server

				@ws.onclose = =>
					@onClose?()
					if !@opened
						cb false

				@ws.onopen = =>
					@ws.send @version
					@sendMessage ['1', version, clientId, dbName, schemaVersion], =>
						@onOpen?()
						@opened = true
						cb true
						@_sendNextMessage()

				@ws.onmessage = (message) =>
					message = message.data
					[code, params...] = message.split '\t'
					console.log 'receive', code, params
					# console.log code, params
					switch code
						when 'r'
							number = params[0]
							responseCode = params[1]
							if responseCode == '0'
								@messageCbs[number] null, params.slice(2)...

							else
								mapping =
									'1': 'invalidClientId'
								@messageCbs[number] mapping[responseCode]

							delete @messageCbs[number]

							@_sending = false
							@onSendFinished?()

							@_sendNextMessage()

						when 'u'
							@onUpdate JSON.parse params[0]


			_ready: ->
				!@_sending && @ws?.readyState == WebSocket.OPEN

			_sendNextMessage: ->
				if @queue.length
					{num:num, params:params} = @queue.shift()
					@_sendMessage num, params


			_sendMessage: (num, params) ->
				@_sending = true
				console.log 'send', num, params
				@ws.send "#{num}\t#{params.join '\t'}"
				@onSendStart?()

			sendMessage: (params, cb) ->
				num = @messageNumber++
				@messageCbs[num] = cb ? ->
				

				if @_ready()
					@_sendMessage num, params
				else
					@queue.push num:num, params:params
