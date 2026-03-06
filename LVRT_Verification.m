%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Model Validation Result Evaluation for LVRT
%% Constant Definitions: U, P, Q, Id, Iq
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Manufacturer "ADPSS_pu" data preprocessing

% Ask user to select the data type of HIL (Hardware-in-the-Loop) data
unit = input('Please enter the HIL data type, 1 for .mat format, 2 for .csv format: ');
if (unit ~= 1) && (unit ~= 2)
    error('Please enter a correct HIL data type.');
end

% Ask user to select the validation mode
unit2 = input('Please enter the validation mode, 1 for viewing results only; 2 for viewing and saving data: ');
if (unit2 ~= 1) && (unit2 ~= 2)
    error('Please enter a correct validation mode.');
end

% Initialize matrix for storing error indicators (5 variables × 9 indicators)
F_dvi = zeros(5,9);
global_variables;          % Load global variables (e.g., error thresholds, Fmax)
fig_num = 19;              % Starting figure number

disp('====== ProcessResult - ADPSS & HIL - LVRT ======');
disp('==F1: Steady-state deviation');
disp('==F2: Transient deviation');
disp('==F3: Maximum deviation');
disp('==FG: Weighted deviation');
disp('==Pre: Pre-fault');
disp('==Trs: During fault');
disp('==Pst: Post-fault');
disp('====== ================================== ======');

% Time window settings for each segment (pre-fault, during-fault, post-fault)
% These times correspond to different fault durations for LVRT cases
time_set = [5150;5625;5920;6214;6705;7000]/1000;   % [s]
% Alternative setting (commented out)
% time_set = [5500;10000;10000;10000;10000;10000]/1000;

% Y-axis labels for the five plots
y_legend = ["\itU\rm/p.u."; "\itP\rm/p.u."; "\itQ\rm/p.u."; "\itI\rm_d/p.u."; "\itI\rm_q/p.u."];

% Load file name lists (assumes FilenameCheck_LVRT defines HIL_filename and ADP_filename)
FilenameCheck_LVRT;

% Apply default figure appearance settings
Figure_Mode;

% Define paths for HIL raw data, ADPSS raw data, and exported results
path_HIL = '../m_tools/HIL_pu';        % HIL raw data path
path_ADP = '../m_tools/ADPSS_Windows_pu'; % ADPSS raw data path
path_Pro = '../m_tools/DataExport';    % Exported results path

%% Loop over test conditions (currently set to only 1 condition, can be expanded)
for file_category = 1:1
    % Find all files in the HIL and ADPSS directories matching the current condition
    HIL_list = dir(fullfile(path_HIL, HIL_filename{file_category}));
    ADP_list = dir(fullfile(path_ADP, ADP_filename{file_category}));
    HIL_name = {HIL_list.name};
    ADP_name = {ADP_list.name};

    %% Process each file (currently set to only 1 file per condition)
    for n = 1:1
        % Construct full file paths
        HILfile = fullfile(path_HIL, HIL_name{n});
        ADPfile = fullfile(path_ADP, ADP_name{n});
        disp(['===Process ', num2str(fig_num), ': ', HIL_name{n}]);
        disp(['===ADPFile ', num2str(fig_num), ': ', ADP_name{n}]);

        % Load HIL data according to selected format
        if unit == 1
            % .mat format
            RawData = load(HILfile);
            ins = fieldnames(RawData);
            PU = RawData.(ins{:,:});   % Extract the variable (assumed matrix)
            PU = PU';                   % Transpose to make time the first column
            PU(:,1) = PU(:,1) - PU(1,1); % Shift time to start at zero
        else
            % .csv format
            RawData = readtable(HILfile, 'VariableNamingRule', 'preserve');
            RawData(:,1) = RawData(:,1) - RawData(1,1); % Shift time
            PU = table2array(RawData);
            % Ensure columns 5 and 6 (Iq and possibly another) are correctly assigned
            PU(:,5) = PU(:,5);
            PU(:,6) = PU(:,6);
        end

        Ts = PU(3,1) - PU(2,1); % Sampling interval (using rows 2 and 3 to avoid possible glitches)

        % Load ADPSS data (always .csv)
        RawData = readtable(ADPfile, 'VariableNamingRule', 'preserve');
        RawData(:,1) = RawData(:,1) - RawData(1,1);
        PreData = table2array(RawData);

        % (Optional) Fix non-monotonic time stamps - commented out
        % for i=1:length(PreData)-1
        %     if PreData(i+1,1)-PreData(i,1) <= 0
        %         PreData(i+1,1) = PreData(i+1,1)+0.00001;
        %     end
        % end

        %% Plot comparison for each of the 5 variables (U, P, Q, Id, Iq)
        for p = 1:5
            plot(PU(:,1), PU(:,p+1), 'r--')   % HIL data (red dashed)
            hold on;
            plot(PreData(:,1), PreData(:,p+1), 'b-') % ADPSS data (blue solid)

            ax = gca;
            ax.XLim = [0, 10];   % Fixed x-axis range (10 seconds)
            % Set y-axis limits: voltage has narrower range
            if p == 1
                ax.YLim = [-0.2, 2];
            else
                ax.YLim = [-3, 3];
            end
            ax.GridLineStyle = ':';
            ax.GridLineWidth = 0.5;
            grid on;
            ylabel(y_legend{p});
            xlabel('\itt\rm/s');

            % Figure positioning and legend
            set(gcf, 'WindowStyle', 'normal');
            set(gcf, 'position', [200, 200, 360, 120]);  % Smaller figure size
            h = legend('Tested', 'ADPSS', 'Location', 'northoutside', 'Orientation', 'horizontal');
            set(h, 'EdgeColor', 'None');
            h.Position = h.Position - [0 0.01 0 0];
            ax.OuterPosition = [0 0 1 0.9];

            % Save figure if requested
            if unit2 == 2
                save_name = ['lvrt', num2str(fig_num), num2str(p), '.jpg'];
                saveas(gcf, fullfile(path_Pro, save_name), 'jpg');
            end
            close;
        end

        %% Data processing for error calculation

        % Determine key time indices (A, B, C) in HIL data
        % A: start of steady-state before fault
        % B: fault inception (voltage drop below 0.89 * pre-fault mean)
        % C: fault clearance
        HIL_Amean = mean(PU(ceil(2/Ts):ceil(4/Ts), 2)); % mean voltage in early steady state (2-4s)

        try
            % Find first point where voltage drops below 0.89 of the mean (fault detection)
            HIL_B = ceil(1.98/Ts) + find(PU(ceil(2/Ts):end, 2) < 0.89 * HIL_Amean, 1);
            if isempty(HIL_B)
                HIL_B = find(PU(:,1) > 5 - 0.02, 1); % fallback to ~5s
            end
        catch
            HIL_B = find(PU(:,1) > 5 - 0.02, 1);
        end
        HIL_A = HIL_B - ceil(2/Ts); % 2 seconds before fault

        % Fault clearance time (C) based on time_set for current n
        HIL_C = find(PU(:,1) > time_set(n) - 0.02, 1);
        HIL_C2 = find(PU(:,1) > time_set(n) + 1.98, 1); % end of post-fault period (2s after clearance)
        HIL_C2t = find(PU(1:end-ceil(1/Ts), 1), 1, 'last'); % last valid index (avoid extrapolation)

        % Corresponding indices in ADPSS data (by time alignment)
        ADP_A = find(PreData(:,1) >= PU(HIL_A,1), 1);
        ADP_B = find(PreData(:,1) >= PU(HIL_B,1), 1);
        ADP_C = find(PreData(:,1) >= PU(HIL_C,1), 1);

        %% Loop over the five variables (U,P,Q,Id,Iq) to compute error metrics
        for nb = 2:6
            % Shift signals by +2 to avoid zero-crossing issues in comparisons
            TestHIL(:,1) = PU(:,nb) + 2;
            TestADP(:,1) = PreData(:,nb) + 2;

            % Mean values in steady-state periods
            mean_Pt  = mean(TestHIL(HIL_B + floor(0.66*(HIL_C-HIL_B)) : HIL_C));   % during fault (last 66%)
            mean_Ps1 = mean(TestHIL(HIL_A + floor(0.66*(HIL_B-HIL_A)) : HIL_B));   % pre-fault (last 66%)
            mean_Ps2 = mean(TestHIL(HIL_C2t : end));                                % post-fault (whole tail)

            % Determine boundaries for transition regions using adaptive thresholds
            comp_max1 = F_error + mean_Pt + 0.1*abs(mean_Pt - mean_Ps1);
            comp_min1 = -F_error + mean_Pt - 0.1*abs(mean_Pt - mean_Ps1);
            % Find last point where signal stays within bounds (end of initial transient)
            HIL_B1t = HIL_B + find(abs([0; TestHIL(HIL_B:HIL_C)]) > comp_max1 | ...
                                    abs([0; TestHIL(HIL_B:HIL_C)]) < comp_min1, 1, 'last');

            comp_max2 = F_error + mean_Ps2 + 0.1*abs(mean_Pt - mean_Ps2);
            comp_min2 = -F_error + mean_Ps2 - 0.1*abs(mean_Pt - mean_Ps2);
            HIL_C1t = HIL_C + find(abs([0; TestHIL(HIL_C:HIL_C2t)]) > comp_max2 | ...
                                    abs([0; TestHIL(HIL_C:HIL_C2t)]) < comp_min2, 1, 'last');

            % Refine indices to ensure at least 0.02s after transition
            HIL_B1 = min([HIL_C-1; find(PU(:,1) > PU(HIL_B1t,1) + 0.02, 1)]);
            HIL_C1 = min([HIL_C2t-1; find(PU(:,1) > PU(HIL_C1t,1) + 0.02, 1)]);
            HIL_C2 = min(length(PU(:,1)), HIL_C1 + ceil(2/Ts)); % ensure 2s post-fault window

            % Corresponding ADPSS indices
            ADP_B1 = find(PreData(:,1) >= PU(HIL_B1,1), 1);
            ADP_C1 = find(PreData(:,1) >= PU(HIL_C1,1), 1);
            ADP_C2 = find(PreData(:,1) >= PU(HIL_C2,1), 1);

            %% (Optional) Debugging section – commented out
            % AA = TestHIL(HIL_B1:HIL_C)-PreData_int2;
            % find(AA==max(abs(AA)))
            % plot(PU(HIL_B1+643,1),PU(HIL_B1+643,nb),'*', Color=[1,0,1])
            % pause(1);
            % close;

            %% Compute error indicators (F1~FG)

            % F1: Mean difference in steady-state segments
            F1pre  = abs(mean(TestHIL(HIL_A:HIL_B))   - mean(TestADP(ADP_A:ADP_B)));
            F1tr   = abs(mean(TestHIL(HIL_B1:HIL_C))  - mean(TestADP(ADP_B1:ADP_C)));
            F1post = abs(mean(TestHIL(HIL_C1:HIL_C2)) - mean(TestADP(ADP_C1:ADP_C2)));

            % F2: Mean difference in transition segments
            F2tr   = abs(mean(TestHIL(HIL_B:HIL_B1))  - mean(TestADP(ADP_B:ADP_B1)));
            F2post = abs(mean(TestHIL(HIL_C:HIL_C1))  - mean(TestADP(ADP_C:ADP_C1)));

            % F3: Maximum absolute difference (after interpolation) in each segment
            PreData_int1 = interp1(PreData(ADP_A:ADP_B,1), TestADP(ADP_A:ADP_B), PU(HIL_A:HIL_B,1), 'linear');
            PreData_int2 = interp1(PreData(ADP_B1:ADP_C,1), TestADP(ADP_B1:ADP_C), PU(HIL_B1:HIL_C,1), 'linear');
            PreData_int3 = interp1(PreData(ADP_C1:ADP_C2,1), TestADP(ADP_C1:ADP_C2), PU(HIL_C1:HIL_C2,1), 'linear');

            F3pre = max(abs(TestHIL(HIL_A:HIL_B) - PreData_int1));
            F3tr  = max(abs(TestHIL(HIL_B1:HIL_C) - PreData_int2));
            F3post= max(abs(TestHIL(HIL_C1:HIL_C2) - PreData_int3));

            % Alternative calculation of F3 (maximum over all segments) – commented out
            % F3 = max([F3pre; F3tr; F3post]);

            % FA, FB, FC: differences in means over broader intervals (pre-fault, fault, post-fault)
            FA = mean(TestHIL(HIL_A:HIL_B)) - mean(TestADP(ADP_A:ADP_B));
            FB = mean(TestHIL(HIL_B:HIL_C)) - mean(TestADP(ADP_B:ADP_C));
            FC = mean(TestHIL(HIL_C:HIL_C2)) - mean(TestADP(ADP_C:ADP_C2));

            % FG: weighted sum of absolute FA, FB, FC
            FG = abs(FA)*0.1 + abs(FB)*0.6 + abs(FC)*0.3;

            % Store all 9 indicators for current variable (row nb-1)
            F_dvi(nb-1, :) = [F1pre, F3pre, F1tr, F2tr, F3tr, F1post, F2post, F3post, FG];

            % Save F_dvi matrix if requested
            if unit2 == 2
                save(fullfile('../m_tools/DataExport', ['Fdvi', num2str(fig_num)]), 'F_dvi');
            end
        end

        %% Check if results satisfy the predefined standard (Fmax)
        if ~(max(F_dvi > Fmax, [], 'all'))
            disp(['   Pass ', num2str(fig_num), ': ', HIL_name{n}]);
        else
            disp(['!!!Do Not Pass ', num2str(fig_num), ': ', HIL_name{n}]);

            % Display the indicators that exceed thresholds
            Fdviout = F_dvi .* (F_dvi > Fmax);
            Fdviout(Fdviout == 0) = NaN;

            % Format output for display
            formattedString = cellfun(@(x) sprintf('%.4f', x), num2cell(Fdviout), 'UniformOutput', false);
            formattedString(cellfun(@(x) strcmp(x, 'NaN'), formattedString)) = {'  //  '};
            [rows, cols] = size(formattedString);
            formattedString = vertcat({'F1-Pre', 'F3-Pre', 'F1-Trs', 'F2-Trs', 'F3-Trs', 'F1-Pst', 'F2-Pst', 'F3-Pst', '  FG  '}, formattedString);
            leftLabels = {'------'; 'U     '; 'P     '; 'Q     '; 'Id    '; 'Iq    '};
            formattedString = horzcat(leftLabels, formattedString);

            % Print table
            for i = 1:size(formattedString, 1)
                row = formattedString(i, :);
                fprintf('%s    ', row{:});
                fprintf('\n');
            end

            Fdvi_error = Fdvi_error + 1; % increment global error counter
        end

        fig_num = fig_num + 1; % move to next figure number

        clear TestADP TestHIL; % clean up for next iteration
    end
end

%%
disp(['=== Number of Faulted Data in LVRT Check: ', num2str(Fdvi_error), ' ===']);
disp('=============== done ===============');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%