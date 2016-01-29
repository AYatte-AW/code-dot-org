#
# Cookbook Name:: cdo-repository
# Recipe:: default
#
require 'etc'
include_recipe 'cdo-github-access'

template "/home/#{node[:current_user]}/.gemrc" do
  source 'gemrc.erb'
  user node[:current_user]
  group node[:current_user]
end

# Sync to the appropriate branch.
adhoc = node.chef_environment == 'adhoc'
branch = adhoc ?
  (node['cdo-repository']['branch'] || 'staging') :
  node.chef_environment

home_path = "/home/#{node[:current_user]}"
git_path = File.join home_path, node.chef_environment

module GitHelper
def git_shared_volume?(git_path, home_path)
  if ::File.directory?(git_path)
    stat = ::File.stat(git_path)
    home_stat = ::File.stat(home_path)
    stat.uid != home_stat.uid || stat.dev != home_stat.dev
  else
    false
  end
end
end
Chef::Resource.send(:include, GitHelper)
Chef::Recipe.send(:include, GitHelper)

# Add the branch to the remote fetch list if not already provided.
execute "fetch-git-branch" do
  cwd git_path
  command "git config --add remote.origin.fetch +refs/heads/#{branch}:refs/remotes/origin/#{branch}"
  not_if "git config --get remote.origin.fetch '^\\+refs/heads/#{branch}:refs/remotes/origin/#{branch}$'", cwd: git_path
end if ::File.directory?(git_path) && !git_shared_volume?(git_path, home_path)

git git_path do
  if node['cdo-github-access'] && node['cdo-github-access']['id_rsa'] != ''
    repository 'git@github.com:code-dot-org/code-dot-org.git'
  else
    repository 'https://github.com/code-dot-org/code-dot-org.git'
  end

  # Make adhoc checkouts as shallow as possible.
  depth 1 if node.chef_environment == 'adhoc'

  # Checkout at clone time, disable the additional checkout step.
  enable_checkout false
  checkout_branch branch
  revision branch

  # Sync the local branch to the upstream branch.
  # Skip git-repo sync when running a shared-volume.
  action git_shared_volume?(git_path, home_path) ? :nothing : :sync
  user node[:current_user]
  group node[:current_user]

end
