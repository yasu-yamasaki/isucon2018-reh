package ISUCON8::Portal::Web::Controller::Admin;
use strict;
use warnings;
use feature 'state';

sub get_index {
    my ($self, $c) = @_;
    return $c->redirect('/admin/dashboard');
}

sub get_login {
    my ($self, $c) = @_;
    if ($c->session->get('admin')) {
        return $c->redirect('/admin');
    }

    return $c->render_admin('admin/login.tx');
}

sub post_login {
    my ($self, $c) = @_;
    state $rule = $c->make_validator(
        name     => { isa => 'Str' },
        password => { isa => 'Str' },
    );

    my $params = $c->validate($rule, $c->req->body_parameters->mixed);
    unless ($params) {
        $c->log->warnf('validate error: %s', $rule->error->{message});
        $c->fillin_form($c->req);
        return $c->render_admin('admin/login.tx', {
            is_error => 1,
        });
    }

    my $user = $c->model('Admin')->find_user($params);
    unless ($user) {
        $c->log->warnf('admin login failed (name: %s)', $params->{name});
        $c->fillin_form($c->req);
        return $c->render_admin('admin/login.tx', {
            is_error => 1,
        });
    }

    $c->session->set(admin => $user->{name});
    return $c->redirect('/admin');
}

sub get_logout {
    my ($self, $c) = @_;
    $c->session->remove('admin');
    $c->redirect('/admin/login');
}

sub get_dashboard {
    my ($self, $c) = @_;
    my $model = $c->model('Admin');

    my $processiong_jobs = $model->get_processing_jobs;
    my $info             = $model->get_information;
    my $scores           = $model->get_team_scores({ limit => 30 });
    my $chart_data       = $model->get_chart_data({
        team_id => 0,
        limit   => 30,
    });
    return $c->render_admin('admin/dashboard.tx', {
        page             => 'dashboard',
        info             => $info,
        processiong_jobs => $processiong_jobs,
        scores           => $scores,
        chart_data       => $chart_data,
    });
}

sub get_jobs {
    my ($self, $c) = @_;
    my $model = $c->model('Admin');

    my $all_jobs = $model->get_all_jobs;
    my $info     = $model->get_information;
    return $c->render_admin('admin/jobs.tx', {
        page     => 'jobs',
        info     => $info,
        all_jobs => $all_jobs,
    });
}

sub get_job_detail {
    my ($self, $c, $captured) = @_;
    state $rule = $c->make_validator(
        job_id => { isa => 'Str' },
    );

    my $params = $c->validate($rule, $captured);
    unless ($params) {
        $c->log->warnf('validate error: %s', $rule->error->{message});
        return $c->res_404;
    }

    my $model = $c->model('Admin');
    my $job   = $model->get_job({ job_id => $params->{job_id} });
    my $info  = $model->get_information;
    return $c->render_admin('admin/job_detail.tx', {
        page => 'jobs',
        info => $info,
        job  => $job,
    });
}

sub get_information {
    my ($self, $c) = @_;

    my $model = $c->model('Admin');
    my $info  = $model->get_information();
    return $c->render_admin('admin/information.tx', {
        page => 'information',
        info => $info,
    });
}

sub post_information {
    my ($self, $c) = @_;
    state $rule = $c->make_validator(
        message => { isa => 'Str' },
    );
    my $params = $c->validate($rule, $c->req->body_parameters->mixed);
    unless ($params) {
        $c->log->warnf('validate error: %s', $rule->error->{message});
        return $c->res_400;
    }

    my $model = $c->model('Admin');
    $model->update_information({ message => $params->{message} });

    my $info = $model->get_information;
    return $c->render_admin('admin/information.tx', {
        page => 'information',
        info => $info,
    });
}

sub get_scores {
    my ($self, $c) = @_;
    my $model = $c->model('Admin');

    my $info   = $model->get_information;
    my $scores = $model->get_team_scores();
    return $c->render_admin('admin/scores.tx', {
        page   => 'scores',
        info   => $info,
        scores => $scores,
    });
}

sub get_servers {
    my ($self, $c) = @_;
    my $model = $c->model('Admin');

    my $info    = $model->get_information;
    my $servers = $model->get_servers;

    my $servers_map = {};
    for my $row (@$servers) {
        my $team_server = $servers_map->{ $row->{team_id} } ||= {
            team_id    => $row->{team_id},
            team_name  => $row->{team_name},
            team_state => $row->{team_state},
            group_id   => $row->{group_id},
            node       => $row->{node},
            servers    => [],
        };
        push @{ $team_server->{servers} }, $row;
    }

    return $c->render_admin('admin/servers.tx', {
        page        => 'servers',
        info        => $info,
        servers_map => $servers_map,
    });
}

sub get_teams {
    my ($self, $c) = @_;
    my $model = $c->model('Admin');

    my $info  = $model->get_information;
    my $teams = $model->get_teams;
    return $c->render_admin('admin/teams.tx', {
        page  => 'teams',
        info  => $info,
        teams => $teams,
    });
}

sub get_team_edit {
    my ($self, $c, $captured) = @_;
    state $rule = $c->make_validator(
        team_id => { isa => 'Str' },
    );

    my $params = $c->validate($rule, $captured);
    unless ($params) {
        $c->log->warnf('validate error: %s', $rule->error->{team_id});
        return $c->render_admin('admin/team_edit.tx', {
            page => 'teams',
        });
    }

    my $team_id     = $captured->{team_id};
    my $admin_model = $c->model('Admin');
    my $team_model  = $c->model('Team');

    my $info        = $admin_model->get_information;
    my $team        = $team_model->get_team({ id => $team_id });
    my $servers     = $team_model->get_servers({ group_id => $team->{group_id} });
    my $jobs        = $team_model->get_team_jobs({ team_id => $team->{id} });
    my $chart_data  = $admin_model->get_team_chart_data({ team_id => $team_id });
    return $c->render_admin('admin/team_edit.tx', {
        page       => 'teams',
        info       => $info,
        team       => $team,
        servers    => $servers,
        jobs       => $jobs,
        chart_data => $chart_data,
    });
}

sub post_team_edit {
    my ($self, $c, $captured) = @_;
    state $capture_rule = $c->make_validator(
        team_id => { isa => 'Str' },
    );

    use Mouse::Util::TypeConstraints;
    state $rule = $c->make_validator(
        state   => { isa => enum([qw/active banned/]) },
        message => { isa => 'Str' },
        note    => { isa => 'Str' },
    );
    no Mouse::Util::TypeConstraints;

    unless ($c->validate($capture_rule, $captured)) {
        $c->log->warnf('validate error: %s', $rule->error->{message});
        $c->fillin_form($c->req);
        return $c->render_admin('admin/team_edit.tx', {
            page     => 'teams',
            is_error => 1,
        });
    }

    my $params = $c->validate($rule, $c->req->body_parameters->mixed);
    unless ($params) {
        $c->log->warnf('validate error: %s', $rule->error->{message});
        $c->fillin_form($c->req);
        return $c->render_admin('admin/team_edit.tx', {
            page     => 'teams',
            is_error => 1,
        });
    }

    $c->model('Admin')->update_team({
        id      => $captured->{team_id},
        state   => $params->{state},
        message => $params->{message},
        note    => $params->{note},
    });

    my $info    = $c->model('Admin')->get_information;
    my $team    = $c->model('Team')->get_team({ id => $captured->{team_id} });
    my $servers = $c->model('Team')->get_servers({ group_id => $team->{group_id} });
    return $c->render_admin('admin/team_edit.tx', {
        page    => 'teams',
        info    => $info,
        team    => $team,
        servers => $servers,
    });
}

sub get_enqueue {
    my ($self, $c) = @_;
    my $model = $c->model('Admin');
    my $info  = $model->get_information;
    $c->render('admin/enqueue.tx', {
        page => 'enqueue',
        info => $info,
    });
}

sub post_enqueue {
    my ($self, $c) = @_;
    state $rule = $c->make_validator(
        team_ids => { isa => 'Str' },
    );

    my $params = $c->validate($rule, $c->req->body_parameters->mixed);
    unless ($params) {
        $c->log->warnf('validate error: %s', $rule->error->{message});
        return $c->res_400;
    }

    my $team_ids  = [
        map { s/(?:^\s+)|(?:\s+$)//gr } split /,/, $params->{team_ids},
    ];
    my $teams     = $c->model('Admin')->get_teams({ ids => $team_ids });
    my $results   = [];
    my $teams_map = +{ map { $_->{id} => $_ } @$teams };
    for my $team_id (@$team_ids) {
        my $team = $teams_map->{ $team_id };
        my ($is_success, $error);
        if ($team) {
            ($is_success, $error) = $c->model('Bench')->enqueue_job({
                team_id  => $team->{id},
                group_id => $team->{group_id},
            });
        }
        else {
            $is_success = 0;
            $error      = sprintf('not found team: %s', $team_id);
        }

        push @$results, {
            team       => $team,
            is_success => $is_success,
            error      => $error,
        };
    }

    return $c->render('admin/enqueue.tx', {
        page    => 'enqueue',
        results => $results,
    });
}

sub get_enqueue_all {
    my ($self, $c) = @_;
    my $model = $c->model('Admin');
    my $info  = $model->get_information;
    $c->render('admin/enqueue_all.tx', {
        page => 'enqueue_all',
        info => $info,
    });
}

sub post_enqueue_all {
    my ($self, $c) = @_;
    my $bench = $c->model('Bench');
    my $teams = $bench->get_teams;

    my $results   = [];
    my $successed = 0;
    my $failed    = 0;
    for my $row (@$teams) {
        my ($is_success, $error) = $bench->enqueue_job({
            team_id  => $row->{id},
            group_id => $row->{group_id},
        });

        $is_success ? $successed++ : $failed++;
        push @$results, {
            team       => $row,
            is_success => $is_success,
            error      => $error,
        };
    }

    $c->render('admin/enqueue_all.tx', {
        page      => 'enqueue_all',
        results   => $results,
        successed => $successed,
        failed    => $failed,
    });
}

1;
