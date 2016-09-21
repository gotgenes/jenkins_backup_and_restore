# Jenkins Configuration Backup and Restore

This repository provides tools necessary for a Jenkins configuration capable of preserving itself and restoring a backed up Jenkins configuration into an operational state.

The objective of this project is to track and backup the minimal amount of information necessary to restore a new Jenkins master in the event of a failure. This does not back up all files in `JENKINS_HOME`; other projects are available that do that. Information that is archived by this project includes the following:

* the general Jenkins configuration
* the configurations for each of the existing jobs
* the list of plugins currently installed and their versions
* the plugin configurations

Files not archived by this project include but are not limited to:

* job artifacts
* workspaces
* the actual plugin files (`.jpi`/`.hpi` files)
* build information files, including those that contain information on the current build number and last successful build number


## Usage

### Set up for backup

#### Clone this repository

Start by cloning this repository into your intended `JENKINS_HOME`.

```
mkdir -p "$JENKINS_HOME"
cd "$JENKINS_HOME"
git clone -o upstream git@github.com:gotgenes/jenkins_configuration_backup_and_restore.git .
```

**NOTE**: While you don't need to provide the `-o upstream`, you will probably want to reserve the remote name of `origin` for [your own remote repository to which you will push for backup](#add-your-backup-remote-location).


##### Cloning into an existing `JENKINS_HOME`

If you already have a `JENKINS_HOME` with existing files existing, you can still apply this project directly into it, however, `git clone` will give you a hard time. Below are the steps to introduce this project into your `JENKINS_HOME` so you can start backing it up:

```
cd /path/to/jenkins_home
git init .
git remote add upstream git@github.com:gotgenes/jenkins_configuration_backup_and_restore.git
git fetch upstream
git reset --hard upstream/master
```

**WARNING**: the above command will overwrite any files you have in your `JENKINS_HOME` that match any paths of files in the Git repository. See [this thread on Stack Overflow](http://stackoverflow.com/questions/2411031/how-do-i-clone-into-a-non-empty-directory) for explanations and alternative solutions.


#### Remove or modify this README

Tailor this README to describe your own Jenkins configuration, or delete it.


#### Add your backup remote location

**NOTE: This step is optional, but highly recommended.**

If you plan to back your configuration up, you can use a remote repository location. Once you know this location, add it as `origin`:

```
git remote add origin <remote_repository_location>
```


#### Invoke the `backup_jenkins_config.sh` script

By default, the `backup_jenkins_config.sh` script will perform the following actions:

1. It will search through your `JENKINS_HOME`, identify any modified, added, or removed configuration files, including those for jobs and plugins.
2. It will check the installed plugins and their versions and record these to a plaintext file.
3. It will make a commit into the Git repository history of all the changes found above.

Optionally, you can pass in the `-p` flag, and after the script has made the commit, it will push to the remote repository specified, i.e.,

```
"$JENKINS_HOME/backup_jenkins_config.sh" -p
```

If you followed the above directions, this should be sufficient for most cases to have a working Jenkins configuration backup.

The `backup_jenkins_config.sh` script supports multiple flags for controlling its behavior and overriding settings, such as what URL is used for connecting to Jenkins when searching for its installed plugins, and what remote repository to use. Please consult this script's own documentation by using the `-h` flag for help:

```
"$JENKINS_HOME/backup_jenkins_config.sh" -h
```


##### Invoke the script through Jenkins

The recommended way to use this script is to let Jenkins, itself, invoke it, by creating a freestyle job that invokes `backup_jenkins_config.sh` on a regular interval (e.g., daily or hourly). In the build section, add an "Execute shell" step, and invoke the script. Assuming you followed the steps above, and that you want to push your changes to the remote branch, the minimum invocation would be

```
"$JENKINS_HOME/backup_jenkins_config.sh" -p
```


### Restoration

#### Restoring the configuration

In the simplest case, you can simply clone from your remote Git repository and use that as your new `JENKINS_HOME`. In the case where you have one or more files already existing in your `JENKINS_HOME`, see [the directions for cloning into an existing `JENKINS_HOME` above](#cloning-into-an-existing-jenkins_home).


#### Restoring the plugins

To restore the plugins, simply invoke the `install_plugins.sh` script:

```
"$JENKINS_HOME/install_plugins.sh"
```

This will download the appropriate `.hpi`/`.jpi` files for your given versions of each plugin as it was most recently recorded.


#### Start Jenkins

That's it; you're ready to start your Jenkins master back up!


## Caveats

**Ensure that the only thing pushing to the remote branch is `backup_jenkins_config.sh` from your Jenkins master.** The  `backup_jenkins_config.sh` script assumes that, if push is enabled (i.e., `-p` is passed as an option), it is safe to push to the remote branch. A key assumption here is that no other account is pushing commits to the remote branch. If other users or processes are pushing new commits to the same remote branch, `backup_jenkins_config.sh` will fail on the push. It is up to you the user to determine how to resolve your particular situation. It is not safe for this script to make any assumption on an automatic resolution on your behalf. You will need to resolve the discrepancy in commits yourself; for example, see [this answer on Stack Overflow](http://stackoverflow.com/a/10298391/38140).


## FAQ

### Why not use SCM Sync Configuration Plugin?

[SCM Sync Configuration Plugin](https://wiki.jenkins-ci.org/display/JENKINS/SCM+Sync+configuration+plugin) is a popular alternative to this project, especially given that it can be installed by Jenkins itself. It does have some drawbacks, however.

1. By default, SCM Sync Configuration Plugin creates a new commit any time any configuration is saved. This can lead to a lot of commits with small changes. (This can also be seen as a pro.) The idea of Jenkins Configuration Backup and Restore is that the user should invoke the `backup_jenkins_config.sh` script whenever they feel is suitable. This means it can be run hourly, daily, ad hoc — whatever you choose and feel is appropriate.
2. SCM Sync Configuration Plugin currently struggles when jobs are deleted or renamed. (See SCM Sync Configuration Plugin issues [15128](https://issues.jenkins-ci.org/browse/JENKINS-15128), [25786](https://issues.jenkins-ci.org/browse/JENKINS-25786), and [38139](https://issues.jenkins-ci.org/browse/JENKINS-38139).) Use of tools like [jenkins-autojobs](http://jenkins-autojobs.readthedocs.io/), which create and destroy jobs with frequency, cause SCM Sync Configuration Plugin to choke on a queue of actions that requires [cumbersome manual intervention](https://issues.jenkins-ci.org/browse/JENKINS-15128?focusedCommentId=192726&page=com.atlassian.jira.plugin.system.issuetabpanels:comment-tabpanel#comment-192726). Backup of configurations will fail until resolved. By contrast, `backup_jenkins_config.sh` relies on Bash and simple Unix tools.
3. SCM Sync Configuration Plugin creates a mirror of portions of `JENKINS_HOME` for its Git repository. In contrast, this project should be the starting basis of your `JENKINS_HOME`. What you see in `JENKINS_HOME` is exactly what will get captured during the backup, and to restore your configuration, you restore the files of your `JENKINS_HOME`.
4. SCM Sync Configuration Plugin does not preserve the plugin information or make it easy to restore those plugins.
