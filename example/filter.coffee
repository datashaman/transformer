util = require('util')
StringDecoder = require('string_decoder').StringDecoder
Transform = require('stream').Transform
util.inherits(JSONParseStream, Transform)

# Gets \n-delimited JSON string data, and emits the parsed objects
JSONParseStream = (options) ->
  if not this instanceof JSONParseStream
    return new JSONParseStream(options)

  Transform.call(@, options)
  @_writableState.objectMode = false
  @_readableState.objectMode = true
  @_buffer = ''
  @_decoder = new StringDecoder('utf8')

JSONParseStream.prototype._transform = (chunk, encoding, cb) ->
  @_buffer += @_decoder.write(chunk)
  # split on newlines
  lines = @_buffer.split(/\r?\n/)
  # keep the last partial line buffered
  @_buffer = lines.pop()
  for l in [0..lines.length]
    line = lines[l]
    try
      obj = JSON.parse(line)
    catch er
      @emit('error', er)
      return
    # push the parsed object out to the readable consumer
    @push(obj)
  cb()

JSONParseStream.prototype._flush = (cb) ->
  # Just handle any leftover
  rem = @_buffer.trim()
  if rem
    try
      obj = JSON.parse(rem)
    catch er
      @emit('error', er)
      return
    
    # push the parsed object out to the readable consumer
    @push(obj)

  cb()
