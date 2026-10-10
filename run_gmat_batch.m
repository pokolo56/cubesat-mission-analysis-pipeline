%% Parametri di Missione e Ground Station
sma_km = 6878.14;       % ~500 km quota
ecc = 0.001;
inc_deg = 97.4;         % SSO
duration_days = 2.0;    % 48 ore

% Coordinate Ground Station (Malo / Vicenza)
gs_lat_deg = 45.66;
gs_lon_deg = 11.40;
gs_alt_km  = 0.12;
min_elev_deg = 10.0;

% Percorso reale verificato dal log di GMAT
gmat_bin_path = 'C:\Users\cacca\OneDrive\Desktop\App\GMAT\bin\GmatConsole.exe';
gmat_output_dir = 'C:\Users\cacca\OneDrive\Desktop\App\GMAT\output';

%% Parametri EPS (CubeSat 3U tipico)
P_gen_sun = 12.0;       % [W]
P_load_day = 6.0;       % [W]
P_load_eclipse = 4.5;   % [W]
battery_capacity_wh = 40.0; % [Wh]
eta_charge = 0.90;

%% 1. Iniezione parametri ed esecuzione GMAT
if ~exist('leo_mission_template.script', 'file')
    error('File leo_mission_template.script non trovato nella cartella corrente.');
end

template_str = fileread('leo_mission_template.script');
run_str = template_str;
run_str = strrep(run_str, 'INSERT_SMA', num2str(sma_km));
run_str = strrep(run_str, 'INSERT_ECC', num2str(ecc));
run_str = strrep(run_str, 'INSERT_INC', num2str(inc_deg));
run_str = strrep(run_str, 'INSERT_DURATION', num2str(duration_days));

temp_script_path = fullfile(pwd, 'temp_run.script');
fid = fopen(temp_script_path, 'w');
fwrite(fid, run_str);
fclose(fid);

fprintf('Esecuzione GMAT in corso...\n');
% Esecuzione diretta con GmatConsole (senza flag problematici)
cmd = sprintf('"%s" "%s"', gmat_bin_path, temp_script_path);
[status, cmdout] = system(cmd);

if status ~= 0
    fprintf('Log console:\n%s\n', cmdout);
    error('Errore durante l''esecuzione di GMAT.');
end

%% 2. Rilevamento e recupero del file di output
local_out = fullfile(pwd, 'output_data.txt');
default_gmat_out = fullfile(gmat_output_dir, 'output_data.txt');

if exist(local_out, 'file')
    target_data_file = local_out;
elseif exist(default_gmat_out, 'file')
    copyfile(default_gmat_out, local_out);
    target_data_file = local_out;
else
    error('File output_data.txt non trovato ne in locale ne nella cartella output di GMAT.');
end

fprintf('Dati trovati con successo! Avvio elaborazione vettoriale...\n');

%% 3. Post-Processing Vettoriale
data = readmatrix(target_data_file);
t_sec = data(:, 1);
t_hours = t_sec / 3600;
r_sat_eci = data(:, 2:4);
N = length(t_sec);

R_earth = 6378.137;
omega_earth = 7.292115e-5;
phi = deg2rad(gs_lat_deg);
lambda_0 = deg2rad(gs_lon_deg);

elev = zeros(N, 1);
azim = zeros(N, 1);
shadow_state = zeros(N, 1);

sun_dir = [cosd(-23.44), sind(-23.44)*cosd(0), sind(-23.44)*sind(0)];
sun_dir = sun_dir / norm(sun_dir);

for k = 1:N
    theta = lambda_0 + omega_earth * t_sec(k);
    r_gs_eci = (R_earth + gs_alt_km) * [cos(phi)*cos(theta), cos(phi)*sin(theta), sin(phi)];
    rho_eci = r_sat_eci(k, :) - r_gs_eci;
    
    up = [cos(phi)*cos(theta), cos(phi)*sin(theta), sin(phi)];
    east = [-sin(theta), cos(theta), 0];
    north = cross(up, east);
    
    rho_up = dot(rho_eci, up);
    rho_east = dot(rho_eci, east);
    rho_north = dot(rho_eci, north);
    rho_horiz = sqrt(rho_east^2 + rho_north^2);
    
    elev(k) = rad2deg(atan2(rho_up, rho_horiz));
    az = rad2deg(atan2(rho_east, rho_north));
    if az < 0, az = az + 360; end
    azim(k) = az;
    
    r_sat = r_sat_eci(k, :);
    s_proj = dot(r_sat, sun_dir);
    if s_proj < 0
        d_perp = norm(r_sat - s_proj * sun_dir);
        if d_perp < R_earth - 20
            shadow_state(k) = 1; % Umbra
        elseif d_perp < R_earth + 20
            shadow_state(k) = 2; % Penumbra
        end
    end
end

%% 4. Analisi Tempi Eclisse ed EPS
dt = [diff(t_sec); mean(diff(t_sec))];
is_umbra = (shadow_state == 1);
is_penumbra = (shadow_state == 2);
is_sun = (shadow_state == 0);

tot_umbra_min = sum(is_umbra .* dt) / 60;
tot_penumbra_min = sum(is_penumbra .* dt) / 60;
tot_sun_min = sum(is_sun .* dt) / 60;
tot_time_min = sum(dt) / 60;

fprintf('\n================ BILANCIO TEMPI ILLUMINAZIONE ================\n');
fprintf('Tempo totale:       %7.1f ore\n', duration_days * 24);
fprintf('Tempo in Sole:      %7.1f min (%5.1f%%)\n', tot_sun_min, (tot_sun_min/tot_time_min)*100);
fprintf('Tempo in Penumbra:  %7.1f min (%5.1f%%)\n', tot_penumbra_min, (tot_penumbra_min/tot_time_min)*100);
fprintf('Tempo in Umbra:     %7.1f min (%5.1f%%)\n', tot_umbra_min, (tot_umbra_min/tot_time_min)*100);
fprintf('===============================================================\n\n');

p_net = zeros(N, 1);
for k = 1:N
    if shadow_state(k) == 0
        p_net(k) = (P_gen_sun - P_load_day) * eta_charge;
    elseif shadow_state(k) == 2
        p_net(k) = (0.5 * P_gen_sun - P_load_eclipse);
    else
        p_net(k) = -P_load_eclipse;
    end
end

battery_energy_wh = zeros(N, 1);
battery_energy_wh(1) = battery_capacity_wh;
for k = 2:N
    battery_energy_wh(k) = battery_energy_wh(k-1) + p_net(k-1) * (dt(k-1) / 3600);
    if battery_energy_wh(k) > battery_capacity_wh
        battery_energy_wh(k) = battery_capacity_wh;
    elseif battery_energy_wh(k) < 0
        battery_energy_wh(k) = 0;
    end
end

soc_pct = (battery_energy_wh / battery_capacity_wh) * 100;
min_soc = min(soc_pct);

fprintf('================ STATISTICHE BATTERIA ========================\n');
fprintf('Capacita Nominale: %.1f Wh\n', battery_capacity_wh);
fprintf('Stato di carica minimo (SoC min): %.1f %%\n', min_soc);
fprintf('Massima profondita di scarica (Max DoD): %.1f %%\n', 100 - min_soc);
fprintf('===============================================================\n\n');

%% 5. Analisi Passaggi GS
is_vis = elev >= min_elev_deg;
diff_vis = diff([0; is_vis; 0]);
aos_idx = find(diff_vis == 1);
los_idx = find(diff_vis == -1) - 1;
n_passes = length(aos_idx);

fprintf('================ RAPPORTO PASSAGGI GS ========================\n');
fprintf('Passaggi sopra i %.1f°: %d\n', min_elev_deg, n_passes);
for i = 1:n_passes
    dur_min = (t_sec(los_idx(i)) - t_sec(aos_idx(i))) / 60;
    max_el = max(elev(aos_idx(i):los_idx(i)));
    fprintf('Passaggio %2d: AOS = %5.2f h | Durata = %5.2f min | Max Elev = %5.1f°\n', ...
        i, t_hours(aos_idx(i)), dur_min, max_el);
end
fprintf('===============================================================\n\n');

%% 6. Grafici
figure('Color', 'w', 'Position', [100, 100, 950, 650]);

subplot(2,1,1);
plot(t_hours, elev, 'Color', [0.6 0.6 0.6]); hold on;
yline(min_elev_deg, '--r', sprintf('Maschera Minima (%.0f°)', min_elev_deg));
for i = 1:n_passes
    idx = aos_idx(i):los_idx(i);
    plot(t_hours(idx), elev(idx), 'b', 'LineWidth', 1.8);
end
grid on;
title('Profilo di Elevazione da Ground Station');
xlabel('Tempo [ore]'); ylabel('Elevazione [deg]');

subplot(2,1,2);
plot(t_hours, soc_pct, 'Color', [0.466 0.674 0.188], 'LineWidth', 1.5); hold on;
yline(min_soc, '--r', sprintf('Min SoC: %.1f%%', min_soc));
grid on;
title('Stato di Carica Batteria (SoC)');
xlabel('Tempo [ore]'); ylabel('SoC [%]');