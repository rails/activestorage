# Active Storage Basics

This guide provides you with all you need to store attachments on your models.

After reading this guide, you will know:

* How to attach files to models.
* How to upload files directly to cloud storage.
* How to retrieve variants on attachment.
* How add a service for a new cloud service.

--------------------------------------------------------------------------------

## Introduction

Active Storage makes it simple to upload and reference files in cloud services,
like Amazon S3 or Google Cloud Storage, and attach those files to Active
Records. It also provides a disk service for testing or local deployments, but
the focus is on cloud storage.

## Compared to other storage solutions

A key difference to how Active Storage works compared to other attachment
solutions in Rails is through the use of built-in
[Blob](https://github.com/rails/activestorage/blob/master/lib/active_storage/blob.rb)
and
[Attachment](https://github.com/rails/activestorage/blob/master/lib/active_storage/attachment.rb)
models (backed by Active Record). This means existing application models do not
need to be modified with additional columns to associate with files. Active
Storage uses GlobalID to provide polymorphic associations via the join model of
`Attachment`, which then connects to the actual `Blob`.

These `Blob` models are intended to be immutable in spirit. One file, one blob.
You can associate the same blob with multiple application models as well. And if
you want to do transformations of a given `Blob`, the idea is that you'll simply
create a new one, rather than attempt to mutate the existing (though of course
you can delete that later if you don't need it).

## Add an Attachment

One attachment:

```ruby
class User < ApplicationRecord
  has_one_attached :avatar
end

user.avatar.attach io: File.open("~/face.jpg"), filename: "avatar.jpg", content_type: "image/jpg"
user.avatar.exist? # => true

user.avatar.purge
user.avatar.exist? # => false

user.avatar.url(expires_in: 5.minutes) # => /rails/blobs/<encoded-key>

class AvatarsController < ApplicationController
  def update
    Current.user.avatar.attach(params.require(:avatar))
    redirect_to Current.user
  end
end
```

## Add Multiple Attachments

Many attachments:

```ruby
class Message < ApplicationRecord
  has_many_attached :images
end
```

```erb
<%= form_with model: @message do |form| %>
  <%= form.text_field :title, placeholder: "Title" %><br>
  <%= form.text_area :content %><br><br>

  <%= form.file_field :images, multiple: true %><br>
  <%= form.submit %>
<% end %>
```

```ruby
class MessagesController < ApplicationController
  def create
    message = Message.create! params.require(:message).permit(:title, :content)
    message.images.attach(params[:message][:images])
    redirect_to message
  end
end
```

## Direct Uploads
## Retrieve Variants of an Attachment
## Add Support for Cloud Service
