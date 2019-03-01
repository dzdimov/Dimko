Role Name
=========

This role is intended to be used when a service needs to be restarted using service (CentOS 6) or systemctl (CentOS 7) commands.

Requirements
------------

A pre-requisite for this role is to be invoked from another role that requests a service restart.

Role Variables
--------------

The variables that are to be used for this role are taken from the role from which this role is invoked.

Example Playbook
----------------

Including an example of how to use your role (for instance, with variables passed in as parameters) is always nice for users too:

    - name: Restart service including role
	  include_role:
	    name: RestartService
        defaults_from:

License
-------

BSD

Author Information
------------------

Dimitar Dimov
dimitar.dimov@armedia.commands
