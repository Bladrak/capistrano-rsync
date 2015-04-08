require File.expand_path("../rsync/version", __FILE__)

namespace :load do
  task :defaults do

    set :rsync_options, []
    set :rsync_copy, "rsync --archive --acls --xattrs"

    # Sparse checkout allows to checkout only part of the repository
    set :rsync_sparse_checkout, []

    # You may not need the whole history, put to false to get it whole
    set :rsync_depth, 1

    # Stage is used on your local machine for rsyncing from.
    set :rsync_stage, "tmp/deploy"

    # Cache is used on the server to copy files to from to the release directory.
    # Saves you rsyncing your whole app folder each time.  If you nil rsync_cache,
    # Capistrano::Rsync will sync straight to the release path.
    set :rsync_cache, "shared/deploy"

    set :rsync_target_dir, ""
  end
end


# NOTE: Please don't depend on tasks without a description (`desc`) as they
# might change between minor or patch version releases. They make up the
# private API and internals of Capistrano::Rsync. If you think something should
# be public for extending and hooking, please let me know!

rsync_cache = lambda do
  cache = fetch(:rsync_cache)
  cache = deploy_to + "/" + cache if cache && cache !~ /^\//
  cache
end

rsync_target = lambda do
  target = !!fetch(:rsync_checkout_tag, false) ? "tags/#{fetch(:branch)}" : "origin/#{fetch(:branch)}"
  target
end

Rake::Task["deploy:check"].enhance ["rsync:hook_scm"]

desc "Stage and rsync to the server (or its cache)."
task :rsync => %w[rsync:stage] do
  on release_roles(:all) do |role|
    user = role.user + "@" if !role.user.nil?

    rsync = %w[rsync]
    rsync.concat fetch(:rsync_options)
    rsync << File.join(fetch(:rsync_stage), File.join(fetch(:rsync_target_dir), ""))
    rsync << "#{user}#{role.hostname}:#{rsync_cache.call || release_path}"

    Kernel.system *rsync
  end
end

namespace :rsync do

  def has_roles?
    return env.filter(release_roles(:all)).any?
  end

  desc 'Locally determine the revision that will be deployed'
  task :set_current_revision do
    next if !has_roles?

    run_locally do
      within fetch(:rsync_stage) do
        rev = capture(:git, 'rev-parse', 'HEAD').strip!
        set :current_revision, rev
      end
    end
  end

  task :hook_scm do
    Rake::Task.define_task("#{scm}:check") do
      invoke "rsync:check"
    end

    Rake::Task.define_task("#{scm}:create_release") do
      invoke "rsync:release"
    end
  end

  task :check do
    next if !fetch(:rsync_cache)
    next if !has_roles?

    on release_roles :all do
      execute :mkdir, '-pv', File.join("#{fetch(:deploy_to)}", "#{fetch(:rsync_cache)}")
    end
  end

  task :create_stage do
    next if File.directory?(fetch(:rsync_stage))
    next if !has_roles?

    if fetch(:rsync_sparse_checkout, []).any?
      init = %W[git init --quiet]
      init << fetch(:rsync_stage)

      Kernel.system *init

      Dir.chdir fetch(:rsync_stage) do
        remote = %W[git remote add origin]
        remote << fetch(:repo_url)
        Kernel.system *remote

        fetch = %W[git fetch --quiet --prune --all -t]
        if !!fetch(:rsync_depth, false)
          fetch << "--depth=#{fetch(:rsync_depth)}"
        end
        Kernel.system *fetch

        sparse = %W[git config core.sparsecheckout true]
        Kernel.system *sparse

        sparse_dir = %W[mkdir .git/info]
        Kernel.system *sparse_dir

        open('.git/info/sparse-checkout', 'a') { |f|
          fetch(:rsync_sparse_checkout).each do |sparse_dir|
            f.puts sparse_dir
          end
        }

        pull = %W[git pull --quiet]
        if !!fetch(:rsync_depth, false)
          pull << "--depth=#{fetch(:rsync_depth)}"
        end
        pull << "origin"
        pull << fetch(:branch)
        Kernel.system *pull
      end
    else
      clone = %W[git clone --quiet]
      clone << fetch(:repo_url, ".")
      clone << fetch(:rsync_stage)
      if !!fetch(:rsync_depth, false)
        clone << "--depth=#{fetch(:rsync_depth)}"
      end
      Kernel.system *clone
    end
  end

  desc "Stage the repository in a local directory."
  task :stage => %w[create_stage] do
    next if !has_roles?

    Dir.chdir fetch(:rsync_stage) do
      update = %W[git fetch --quiet --all --prune]
      if !!fetch(:rsync_depth, false)
        update << "--depth=#{fetch(:rsync_depth)}"
      end
      Kernel.system *update

      checkout = %W[git reset --quiet --hard #{rsync_target.call}]
      Kernel.system *checkout
    end
  end

  desc "Copy the code to the releases directory."
  task :release => %w[rsync] do
    # Skip copying if we've already synced straight to the release directory.
    next if !fetch(:rsync_cache)
    next if !has_roles?

    copy = %(#{fetch(:rsync_copy)} "#{rsync_cache.call}/" "#{release_path}/")
    on roles(:all).each do execute copy end
  end

  # Matches the naming scheme of git tasks.
  # Plus was part of the public API in Capistrano::Rsync <= v0.2.1.
  task :create_release => %w[release]
end
