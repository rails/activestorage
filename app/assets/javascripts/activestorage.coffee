#= rails_ujs
#= export ActiveStorage
#= require spark-md5

@ActiveStorage =
  directUploadSelector: 'input[data-direct-upload]'
  directUploadButtonSelector: 'input[type=submit]'

  setSgid: (input, response) =>
    form = input.parentNode
    sgidInput = document.createElement('input')
    sgidInput.setAttribute('type', 'hidden')
    sgidInput.setAttribute('name', 'sgid')
    sgidInput.setAttribute('value', response.sgid)
    form.appendChild(sgidInput)

  disableFormSubmit: (input) =>
    form = input.parentNode
    button = form.querySelector(ActiveStorage.directUploadButtonSelector)
    button.setAttribute('disabled', true)

  enableFormSubmit: (input) =>
    form = input.parentNode
    button = form.querySelector(ActiveStorage.directUploadButtonSelector)
    button.removeAttribute('disabled', true)

  upload: (input, file) =>
    blobSlice = File::slice or File::mozSlice or File::webkitSlice
    chunkSize = 2097152
    chunks = Math.ceil(file.size / chunkSize)
    currentChunk = 0
    spark = new (SparkMD5.ArrayBuffer)
    fileReader = new FileReader

    formData = new FormData
    formData.append 'blob[filename]', file.name
    formData.append 'blob[byte_size]', file.size
    formData.append 'blob[content_type]', file.type

    loadNext = ->
      start = currentChunk * chunkSize
      end = if start + chunkSize >= file.size then file.size else start + chunkSize
      fileReader.readAsArrayBuffer blobSlice.call(file, start, end)
      return

    fileReader.onload = (e) ->
      spark.append e.target.result
      currentChunk++

      if currentChunk < chunks
        loadNext()
      else
        formData.append 'blob[checksum]', spark.end().toString()
        uploadFiles(formData)
      return

    fileReader.onerror = ->
      console.warn 'oops, something went wrong.'
      return

    uploadFiles = (formData) ->
      fetch('/rails/active_storage/direct_uploads',
        method: 'POST'
        body: formData
      ).then((response) ->
        return response.json()
      ).then (directUploadDetails) ->
        fetch(directUploadDetails.url,
          method: 'PUT'
          headers: { 'Content-Type': file.type }
          body: file
        ).then (response) ->
          if response.status == 200
            ActiveStorage.setSgid(input, directUploadDetails)
            ActiveStorage.enableFormSubmit(input)

    loadNext()
    return

document.addEventListener 'DOMContentLoaded', ->
  Rails.$(ActiveStorage.directUploadSelector).forEach (input) ->
    ActiveStorage.disableFormSubmit(input)

    input.addEventListener 'change', ->
      index = 0
      while index < @files.length
        ActiveStorage.upload(input, @files[index])

        index++
