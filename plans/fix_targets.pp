# @summary Plan to carry out automated fixes found by the health_check task
plan phc::fix_targets(
  TargetSpec $targets,
  Boolean    $target_noop_state      = false,
  Integer    $target_runinterval     = 1800,
  Boolean    $target_service_enabled = true,
  Enum['running', 'stopped'] $target_service_running = 'running'
) {

  apply_prep($targets)
  without_default_logging() || {
    # Instead of checking all config values, we could do this with each config value.
    # It's more verbose, but doesn't require finding each resource
    $config_state = run_task('phc::check_config', $targets, '_catch_errors' => true)
    unless $config_state.ok {
        out::message("Config health check failed for ${$config_state.error_set.targets}")
    }

    $config_state.ok_set.each |$result| {
      $t = get_target($result.target)
      $t.set_resources($result.value['_output'])

      # ...what should this title be?
      $noop = $t.lookup_resource('puppetnoop', 'noop')
      $noop.add_event({'noop_health_check' => { 'success' => true } })
      $noop.set_desired_state({ 'noop' => $target_noop_state })

      $runinterval = $t.lookup_resource('puppetruninterval', 'runinterval')
      $runinterval.add_event({'health_check' => { 'success' => true }})
      $runinterval.set_desired_state({ 'runinterval' => $target_runinterval })
    }

    $service_state = run_task('phc::service_health', $targets, '_catch_errors' => true)
    unless $service_state.ok {
        out::message("Service health check failed for ${$service_state.error_set.targets}")
    }

    $service_state.ok_set.each |$result| {
      $r = $result.value + { 'desired_state' => { 'enabled' => $target_service_enabled,
                                                  'ensure' => $target_service_running },
                             'events' => [{'service_health_chck' => { 'success' => true } }] }
      $ri = $result.target.set_resources($r)
    }
    $t = get_targets($targets)
    return $t.map |$t| { $t.resources }

    # Apply desired state here
    # apply_resources($noop_state.ok_set.targets)

#    $first_check = run_task('phc::agent_health',
#                              $targets,
#                              target_noop_state      => $target_noop_state,
#                              target_service_enabled => $target_service_enabled,
#                              target_service_running => $target_service_running,
#                              target_runinterval     => $target_runinterval,
#                              '_catch_errors'        => true
#                            )
#    # Loop around the results from the fleet wide check to
#    # see where we stand and what needs to be fixed.
#    $first_check.each | $result | {
#      $target = $result.target.name
#      # Return error for those that couldn't run the health check
#      unless $result.ok {
#        notice "${target},1,health check failed"
#        next()
#      }
#
#      # Return clean for those that don't have any issues
#      if $result.value['state'] == 'clean' {
#        notice "${target},0,heath check passed"
#        next()
#      }
#
#      $response = $result.value
#
#      # Fix the noop issues
#      if $response['issues']['noop'] {
#        $noop = run_task('phc::fix_noop', $target, target_state => $target_noop_state, '_catch_errors' => true)
#        if $noop.ok {
#          notice "${target},3,noop fixed"
#        } else {
#          notice "${target},4,could not fix noop"
#        }
#      }

      # Fix the lockfile issues
      if $response['issues']['lock_file'] {
        $lockfile = run_task('phc::fix_lockfile', $target, '_catch_errors' => true)
        if $lockfile.ok {
          notice "${target},3,lockfile fixed"
        } else {
          notice "${target},4,could not fix lockfile"
        }
      }

      # Fix the runinterval issues
#      if $response['issues']['runinterval'] {
#        $runinterval = run_task('phc::fix_runinterval', $target, target_state => $target_runinterval, '_catch_errors' => true)
#        if $runinterval.ok {
#          notice "${target},3,runinterval fixed"
#        } else {
#          notice "${target},4,could not fix runinterval"
#        }
#      }
#
#      # Fix last_run issue
#      if $response['issues']['last_run'] {
#        $last_run = run_command('puppet agent -t', $target, '_catch_errors' => true)
#        if $last_run.ok {
#          notice "${target},3,puppet agent run"
#        } else {
#          notice "${target},4,puppet agent failed"
#        }
#      }
#
#      # Fix service enabled issue
#      if $response['issues']['enabled'] {
#
#        $enabled_action = $target_service_enabled ? {
#          true  => 'enable',
#          false => 'disable',
#        }
#
#        $enabled = run_task('service', $target, name => 'puppet', action => $enabled_action, '_catch_errors' => true)
#        if $enabled.ok {
#          notice "${target},3,puppet service enabled set to ${target_service_enabled}"
#        } else {
#          notice "${target},4,puppet service enabled not able to be set to ${target_service_enabled}"
#        }
#      }
#
#      # Fix service running issue
#      if $response['issues']['running'] {
#
#        $service_action = $target_service_running ? {
#          true  => 'start',
#          false => 'stop',
#        }
#
#        $running = run_task('service', $target, name => 'puppet', action => $service_action, '_catch_errors' => true)
#        if $running.ok {
#          notice "${target},3,puppet service set to ${target_service_running}"
#        } else {
#          notice "${target},4,puppet service not able to be set to ${target_service_running}"
#        }
#      }

    # Do the second run to validate that things have been fixed
    $second_check = run_task('phc::agent_health',
                                $target,
                                target_noop_state      => $target_noop_state,
                                target_service_enabled => $target_service_enabled,
                                target_service_running => $target_service_running,
                                target_runinterval     => $target_runinterval,
                                '_catch_errors' => true
                              )
    $second_check.each | $result | {
      $result.value['issues'].each | $issue | {
        # Return any residual issues
        notice "${target},100,${issue[1]}"
      }
    }
  }
}
