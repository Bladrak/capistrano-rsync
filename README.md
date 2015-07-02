Capistrano::Rsync for Capistrano v3
===================================

[![Join the chat at https://gitter.im/Bladrak/capistrano-rsync](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/Bladrak/capistrano-rsync?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

This repository is a fork of https://github.com/moll/capistrano-rsync which doesn't seem to be maintained anymore.

It has all the capabilities of the original repo, and some other features. Moreover, I will try to maintain it.  

[![Gem Version](https://badge.fury.io/rb/capistrano-rsync-bladrak.svg)](http://badge.fury.io/rb/capistrano-rsync-bladrak)
[gem-badge]: https://badge.fury.io/rb/capistrano-rsync-bladrak.svg

**Deploy with Rsync** to your server from any local (or remote) repository when
using [**Capistrano**](http://www.capistranorb.com/).  Saves you from having to
install Git on your production machine and allows you to customize which files
you want to deploy. Also allows you to easily precompile things on your local
machine before deploying.

### Tour
- Works with the new [**Capistrano v3**](http://www.capistranorb.com/) ([source
  code](https://github.com/capistrano/capistrano)) versions `>= 3.0.0pre14` and
  `< 4`.
- Suitable for deploying any apps, be it Ruby, Rails, Node.js or others.  
- Exclude files from being deployed with Rsync's `--exclude` options.
- Precompile files or assets easily before deploying, like JavaScript or CSS.
- Caches your previously deployed code to speed up deployments ~1337%.
- Currently works only with Git (as does Capistrano v3), so please shout out
  your interest in other SCMs.

Added features
--------------

Compared to moll's version, I added the following features:
* setting the ``:rsync_target_dir`` option in order to choose where the code will be stored locally
* implemented a ``set_current_revision`` task to be compliant with Capistrano
* added an option to sparse checkout the repository before rsyncing it, improving performance for large repositories
* added an option to limit the clone depth (defaults to 1) to limit used space while deploying


Using
-----
Install with:
```
gem install capistrano-rsync-bladrak
```

Set rsync as the SCM to use
```
set :scm, :rsync
```

Set some `rsync_options` to your liking:
```ruby
set :rsync_options, %w[--recursive --delete --delete-excluded --exclude .git*]
```

And after setting regular Capistrano options, deploy as usual!
```
cap deploy
```

### Implementation
1. Clones and updates your repository to `rsync_stage` (defaults to
   `tmp/deploy`) on your local machine.
2. Checks out the branch set in the `branch` variable (defaults to `master`).
3. If `rsync_cache` set (defaults to `shared/deploy`), rsyncs to that directory
   on the server.
4. If `rsync_cache` set, copies the content of that directory to a new release
   directory.
5. If `rsync_cache` is `nil`, rsyncs straight to a new release directory.

After that, Capistrano takes over and runs its usual tasks and symlinking.

### Exclude files from being deployed
If you don't want to deploy everything you've committed to your repository, pass
some `--exclude` options to Rsync:
```ruby
set :rsync_options, %w[
  --recursive --delete --delete-excluded
  --exclude .git*
  --exclude /config/database.yml
  --exclude /test/***
]
```

### Precompile assets before deploy
Capistrano::Rsync runs `rsync:stage_done` before rsyncing. Hook to that like this:
```ruby
task :precompile do
  Dir.chdir fetch(:rsync_stage) do
    system "rake", "assets:precompile"
  end
end

after "rsync:stage_done", "precompile"
```

### Deploy release without symlinking the current directory
```
cap rsync:release
```

Troubleshooting
---------------
If you need to hook after rsync:stage_done in your deploy.rb, the rsync namespace is not loaded yet.

So do it like this in your deploy.rb:
```
namespace :rsync do
    # Create an empty task to hook with. Implementation will be come next
    task :stage_done

    # Then add your hook
    after :stage_done, :my_task do
      # Do some stuff.
    end
end
```


Configuration
-------------
Set Capistrano variables with `set name, value`.

Name          | Default | Description
--------------|---------|------------
repo_url      | `.` | The path or URL to a Git repository to clone from.  
branch        | `master` | The Git branch to checkout.  
rsync_stage   | `tmp/deploy` | Path where to clone your repository for staging, checkouting and rsyncing. Can be both relative or absolute.
rsync_cache   | `shared/deploy` | Path where to cache your repository on the server to avoid rsyncing from scratch each time. Can be both relative or absolute.<br> Set to `nil` if you want to disable the cache.
rsync_options | `[]` | Array of options to pass to `rsync`.
rsync_sparse_checkout | `[]` | Array of directories to checkout (checks out all if empty)
rsync_depth   | `1` | Sets the --depth argument value for the git operations; this is set to 1 by default as you won't need the git history
rsync_checkout_tag  | `false` | Is the ``:branch`` symbol containing a branch or a tag?
rsync_copy    | `rsync --archive --acls --xattrs` | The command used to copy from remote cache to remote release
rsync_target_dir | `.` | The local directory within ``:rsync_stage`` to clone to & deploy (useful if you want to keep cache of several branches/tags for instance)
enable_git_submodules | `false` | Should we fetch submodules as well?


License
-------
Capistrano::Rsync is released under a *Lesser GNU Affero General Public
License*, which in summary means:

- You **can** use this program for **no cost**.
- You **can** use this program for **both personal and commercial reasons**.
- You **do not have to share your own program's code** which uses this program.
- You **have to share modifications** (e.g bug-fixes) you've made to this
  program.

For more convoluted language, see the `LICENSE` file.


About
-----
**[Andri Möll](http://themoll.com)** made this happen.  
[Monday Calendar](https://mondayapp.com) was the reason I needed this.

**[Hugo Briand](http://about.me/hbriand)** forked it, maintains it, and adds some features.
