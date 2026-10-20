# The 0.5.x names, kept as aliases

Every function rmoriebricklayer 0.5.13 exported that 1.0.0 renamed is
still callable by its old name, with its old argument names and its old
defaults: each alias forwards to the new function. Allowed values that
were renamed (`"mean_bootstrap"` is now `"meanboot"`) are translated on
the way, as are old argument names passed through `...`. `rate()`,
`rate_change()`, `share()` and `yoy_summary()` stay S3 generics, so
methods written for them still dispatch. An option set under its 0.5.x
name (`rmoriebricklayer.xmss_index_file`, `rmoriebricklayer.data_cache`
...) is read when the new name is not set. The reference documentation
lives on the new name; this page only lists the aliases.

## Details

Results are not translated: their columns and fields carry the new
names. The last table lists every renamed one, so old code that reads a
result can be updated.

## The map

Old name, then the new one.


    admissions                                 admits
    adp_from_counts                            adpcnts
    advection_diffusion_2d                     advdif2d
    agent_bundle                               agentbndl
    analyse_table                              anltab
    apply_schema_validation                    schval
    ascii_fallback                             asciifb
    attributable_fraction                      attrfrac
    audit_categories                           audcats
    band_sensitivity                           bandsens
    band_values                                bandvals
    benford_test                               benfordtst
    bricklayer_cli                             blcli
    bricklayer_data_load                       dload
    bricklayer_data_manifest                   dmnf
    bricklayer_data_tables                     dtabs
    bricklayer_download                        bldl
    bricklayer_explain_error                   explerr
    bricklayer_fetch_parse_siu                 siufprs
    bricklayer_fetch_siu                       siufetch
    bricklayer_json_base64_dec                 jsb64dec
    bricklayer_json_base64_enc                 jsb64enc
    bricklayer_json_base64url_dec              jsb64udec
    bricklayer_json_base64url_enc              jsb64uenc
    bricklayer_json_serialize                  jsser
    bricklayer_json_unserialize                jsunser
    bricklayer_llm_ask                         llmask
    bricklayer_llm_chat                        llmchat
    bricklayer_llm_config                      llmcfg
    bricklayer_llm_login                       dlogin
    bricklayer_llm_logout                      dlogout
    bricklayer_llm_models                      llmmdls
    bricklayer_llm_providers                   llmprvd
    bricklayer_llm_route_info                  llmrte
    bricklayer_llm_status                      llmstat
    bricklayer_palette                         blpal
    bricklayer_parse_siu                       siuprs
    bricklayer_plot_options                    plotopt
    bricklayer_progress                        blprog
    bricklayer_services                        svcs
    bricklayer_siu_iso_date                    siudate
    bricklayer_siu_resolve_so                  siuso
    bricklayer_siu_schema                      siusch
    bricklayer_siu_text                        siutxt
    briggs_plume_rise                          briggs
    capsule_attest                             cpsatst
    capsule_bundle                             cpsbndl
    capsule_bundle_read                        cpsbndlrd
    capsule_bundle_verify                      cpsbndlvrf
    capsule_check_attestation                  cpschkatst
    capsule_drift                              cpsdrft
    capsule_falsify                            cpsfals
    capsule_power                              cpspwr
    capsule_report                             cpsrpt
    capture_dependencies                       capdeps
    capture_environment                        capenv
    carbon_intensity                           co2int
    carbon_intensity_table                     co2inttab
    case_flow                                  caseflow
    cert_chain_verify                          certchnvrf
    cert_parse                                 certprs
    chain_append                               chnapp
    chain_head                                 chnhead
    chain_new                                  chnnew
    chain_seal                                 chnseal
    chain_verify                               chnvrf
    change_envelope                            chgenv
    chunk_file                                 chnkfile
    cite_capsule                               citecps
    clean_column_names                         clncolnms
    clearance_decomposition                    clrdcmp
    compute_footprint                          co2fp
    core_blake2b                               cblake2b
    core_bootstrap_mean                        cbootmean
    core_cor                                   ccorr
    core_cor_spearman                          cspr
    core_cov                                   ccovm
    core_crc32                                 ccrc32
    core_digest_equal                          cdgsteq
    core_dist                                  cdistm
    core_gamma_cdf                             cgamcdf
    core_hawkes_fit                            chwkfit
    core_hawkes_jitter                         chwkjit
    core_hawkes_nll                            chwknll
    core_hawkes_residuals                      chwkres
    core_hmac_sha256                           chmac
    core_ipw_weights                           cipw
    core_iqr                                   ciqr
    core_mad                                   cmad
    core_median                                cmed
    core_midranks                              cmidrk
    core_moments                               cmom
    core_normal_logpdf                         cnormlpdf
    core_normal_pdf                            cnormpdf
    core_quantile                              cqnt
    core_sd                                    csdev
    core_sha512                                csha512
    core_trimmed_mean                          ctrmmean
    core_tukey_fences                          ctkyfnc
    core_uniforms                              cunif
    core_var                                   cvari
    core_weighted                              cwtd
    core_winsorized_mean                       cwinsmean
    correlation_table                          cortbl
    count_trend                                cnttrnd
    cramers_v                                  cramerv
    crc32_file                                 crc32file
    crf_no2                                    crfno2
    crf_pm25                                   crfpm25
    crime_density                              crmdens
    decode_codes                               deccodes
    decode_labelled                            declbld
    derive_key                                 drvkey
    detect_location                            dtctloc
    digest_object                              dgstobj
    disposition_mix                            dispmix
    distinct_count                             dstncnt
    distinct_sketch                            dstnskch
    download_data                              dldata
    drbg_generate                              drbggen
    drbg_new                                   drbgnew
    drbg_reseed                                drbgrsd
    drift_calibrate                            drftcal
    drift_chisq                                drftchisq
    drift_homogeneity                          drfthomog
    drift_ks                                   drftks
    drift_psi                                  drftpsi
    drop_constant                              drpconst
    drop_empty                                 drpempty
    duplicate_rows                             duprows
    eb_rates                                   ebrates
    environment_diff                           envdiff
    evalue_rr                                  evlrr
    expand_bands                               expbands
    expected_counts                            expcnts
    exposure_concentration_index               expconcidx
    exposure_response_plr                      exprspplr
    falsify_family                             falsfam
    fips_key                                   fipskey
    fips_keygen                                fipskg
    fips_mu                                    fipsmu
    fips_public_key                            fipspubkey
    fips_sign_mu                               fipssignmu
    fips_sizes                                 fipssz
    fips_verify_mu                             fipsvrfmu
    fiscal_year_label                          fylbl
    footprint_equivalents                      fpeqv
    frequency_table                            freqtbl
    friendly_download                          fdl
    funnel_limits                              fnllim
    gaussian_plume                             gplume
    gaussian_puff                              gspuff
    gini                                       ginicoef
    guard_binary                               grdbin
    guard_levels                               grdlvls
    guard_recode                               grdrcd
    hill_tail_index                            hilltlidx
    hotspot_persistence                        hotpers
    hqc_compress_key                           hqccmpkey
    hqc_decapsulate                            hqcdecap
    hqc_encapsulate                            hqcencap
    hqc_keygen                                 hqckg
    hqc_public_key                             hqcpubkey
    hqc_sizes                                  hqcsz
    hurwitz_zeta                               hurwzeta
    infer_schema                               infsch
    inline_hist                                inlhist
    install_cli                                instcli
    json_gzip_decode                           jsgzdec
    json_gzip_encode                           jsgzenc
    kem_decapsulate                            kemdecap
    kem_encapsulate                            kemencap
    kem_keygen                                 kemkg
    kem_public_key                             kempubkey
    kem_sizes                                  kemsz
    knox_test                                  knoxtst
    lagrangian_particles                       lagrprt
    life_table                                 lifetbl
    load_provenance                            loadprov
    lorenz                                     lorenzc
    mahalanobis_outliers                       mahaoutl
    make_manifest                              mkmnf
    make_synthetic_column                      mksyncol
    make_synthetic_csv                         mksyncsv
    manifest_canonical                         mnfcanon
    manifest_digest                            mnfdgst
    manifest_recompute                         mnfrcmp
    manifest_record_seed                       mnfrecseed
    manifest_restore_seed                      mnfrstseed
    mcar_test                                  mcartst
    merkle_leaves                              mrklvs
    merkle_proof                               mrkprf
    merkle_root                                mrkroot
    merkle_verify                              mrkvrf
    missing_runs                               missruns
    missingness_map                            missgrid
    missingness_pattern                        misspat
    missingness_summary                        misssmry
    morans_i                                   morani
    mortality_displaced                        mortdisp
    odds_ratio_check                           orchk
    online_summary                             onlsmry
    oqs_keygen                                 oqskg
    oqs_public_key                             oqspubkey
    parse_bands                                prsbands
    period_days                                perdays
    pg_sigmas                                  pgsig
    plot_funnel                                plotfnl
    plot_lorenz                                plotlrnz
    plr_crossfit                               plrcf
    plume_field                                plmfld
    pollution_burden                           polbrdn
    pollution_burden_by_area                   polbrdarea
    pollution_report_text                      polrpttxt
    pqc_backends                               pqcbknd
    prereg_check                               prrgchk
    prereg_declare                             prrgdecl
    profile_columns                            profcols
    published_bounds                           pubbnd
    random_bytes                               rndbytes
    rapl_available                             raplok
    rate                                       rtcalc
    rate_change                                ratechg
    recode_manifest                            rcdmnf
    record                                     recrd
    region_coverage                            rgncov
    region_map_compare                         rgnmapcmp
    region_map_from_points                     rgnmappts
    region_map_integrity                       rgnmapintg
    region_map_second_route                    rgnmapalt
    relabel                                    relbl
    relabel_forensics                          rlblfrns
    report_analysis                            rptanl
    report_markdown                            rptmd
    reservoir_indices                          rsvidx
    reservoir_sample                           rsvsmp
    resolve_via_arcgis                         rslvarc
    resolve_via_ckan                           rslvckan
    resolve_via_ckan_search                    rslvckns
    resolve_via_socrata                        rslvsoc
    revocation_fetch                           rvkfetch
    rule                                       rul
    rule_between                               rulebtw
    rule_col_count                             rulecolcnt
    rule_complete_rows                         rulecmpl
    rule_distinct_rows                         ruledstn
    rule_in_set                                ruleinset
    rule_increasing                            ruleincr
    rule_not_null                              rulenull
    rule_regex                                 rulerx
    rule_unique                                ruleuniq
    rule_within_n_mads                         rulemad
    scan_adjust                                scanadj
    sha512_file                                sha512file
    share                                      shrs
    sir                                        stdinc
    sketch_merge                               skchmrg
    stay_summary                               staysmry
    step_change                                stepchg
    stock_flow                                 stkflow
    summary_merge                              smrymrg
    summary_stats                              smrystat
    summary_update                             smryupd
    survey_compare                             svycmp
    survey_design                              svydes
    survey_estimate                            svyest
    timestamp_info                             tsinfo
    timestamp_verify                           tsvrf
    to_ascii                                   toascii
    top_correlations                           topcors
    top_share                                  topshr
    transfer_verify                            xfrvrf
    trend_test                                 trndtst
    use_capsule_template                       usecpstmpl
    validate_rules                             valrules
    validate_schema                            valsch
    verify_capsule                             vrfcps
    verify_marginals                           vrfmrg
    verify_pollution                           vrfpol
    verify_recode                              vrfrcd
    verify_recode_manifest                     vrfrcdmnf
    verify_sha256                              vrfsha256
    wayback_retry                              wbrtry
    wayback_save                               wbsave
    wayback_snapshot_url_native                wbsnpnat
    write_manifest_json                        wrmnfjs
    write_recode_manifest                      wrrcdmnf
    write_summary_txt                          wrsmrytxt
    write_text_fallback                        wrtxtfb
    xmss_advance                               xmssadv
    xmss_forget_used_indices                   xmssfgt
    xmss_register_key                          xmssregkey
    yoy_bounds                                 yoybnd
    yoy_csv                                    yoycsv
    yoy_html                                   yoyhtml
    yoy_json                                   yoyjs
    yoy_label                                  yoylbl
    yoy_markdown                               yoymd
    yoy_palettes                               yoypals
    yoy_pdf                                    yoypdf
    yoy_pvalues                                yoypv
    yoy_summary                                yoysmry
    yoy_tsv                                    yoytsv
    yoy_write                                  yoywr

## Renamed allowed values

Alias, argument, then each old value and the value it is translated to.


    analyse_table              direction  higher_is_better -> higher,
                                          lower_is_better -> lower
    crf_no2                    outcome    all_cause_mortality -> allcause,
                                          childhood_asthma -> chiast
    crf_pm25                   outcome    all_cause_mortality -> allcause
    pollution_burden           outcome    all_cause_mortality -> allcause,
                                          childhood_asthma -> chiast
    pollution_burden_by_area   outcome    all_cause_mortality -> allcause,
                                          childhood_asthma -> chiast
    survey_design              type       mean_bootstrap -> meanboot
    verify_pollution           outcome    all_cause_mortality -> allcause,
                                          childhood_asthma -> chiast

## Renamed result columns and fields

The 0.5.13 page, then each old name and the name the result has now.


    advection_diffusion_2d: sigma_y -> sigmay, sigma_z -> sigmaz, final_rise -> finalrise,
      x_final -> xfinal, diffusion_number -> difn, stability_number -> stabn,
      mean_y -> meany
    analyse_table: p_adjusted -> padj, combined_pct_lower -> compctlo,
      combined_pct_upper -> compctup, rate_change -> ratechg, trend_p -> trndp,
      rate_ratio -> rateratio, rate_ratio_lower -> rateratiolo,
      rate_ratio_upper -> rateratioup, n_rows -> nrows
    band_sensitivity: relative_span -> relspan
    benford_test: log_p_value -> logpvalue
    bricklayer_siu_schema: is_count -> count
    capsule_drift: js_divergence -> jsdiv, n_reference -> nref, n_current -> ncur,
      any_drift -> anydrft
    capsule_power: smallest_detected -> smadet
    capsule_report: n_rows -> nrows
    case_flow: rolling_clearance -> rolclr, rolling_lower -> rollo, rolling_upper -> rolup,
      pending_change -> penchg, periods_to_clear -> pertoclear, cumulative_net -> cumnet,
      case_flow -> caseflow
    cert_chain_verify: at_time -> attm
    change_envelope: change_lower -> chglo, change_upper -> chgup, pct_lower -> pctlo,
      pct_upper -> pctup, rate_lower -> ratelo, rate_upper -> rateup,
      previous_population -> prepop, previous_rate_lower -> preratelo,
      previous_rate_upper -> prerateup
    clean_column_names: original_names -> orignms
    clearance_decomposition: rate_effect -> rateeff, mix_effect -> mixeff,
      standardised_on_base -> staonbase, standardised_on_average -> staonave,
      rate_ratio -> rateratio
    compute_footprint: duration_s -> durs, cpu_time_s -> cputms, usage_mode -> usagemode,
      memory_gb -> memgb, energy_kwh -> enekwh, co2e_g -> co2eg, carbon_intensity -> co2int
    core_hawkes_fit: baseline_params -> basepar, branching_ratio -> braratio,
      kernel_params -> kerpar, k_params -> kpar, ks_stat -> ksstat, ks_pvalue -> kspva,
      at_bound -> atbound
    correlation_table: n_pairs -> nprs
    count_trend: rate_ratio -> rateratio, log_slope -> logslope
    cramers_v: min_expected -> minexp, cells_below -> cellsbelow
    crf_no2: log_rr -> logrr, rr_lower -> rrlo, rr_upper -> rrup,
      reference_conc -> refconc, exposure_conc -> expconc, beta_per_10 -> betaper10,
      beta_per_10_ci -> betaper10ci, rr_per_unit -> rrperunit
    crime_density: area_km2 -> areakm2
    download_data: target_path -> tpath
    drift_calibrate: false_alarm_rate -> falsealarmrate, any_flag -> anyflag,
      alpha_familywise -> alphafam
    drift_chisq: log_p_value -> logpvalue
    drift_homogeneity: log_p_value -> logpvalue
    drift_ks: n_eff -> neff
    drift_psi: js_divergence -> jsdiv
    evalue_rr: evalue_point -> evlpoint, evalue_limit -> evllimit
    exposure_concentration_index: concentration_index -> concidx, exposure_mean -> expomean
    exposure_response_plr: se_analytic -> seana, se_bootstrap -> seboot,
      ci_lower_bs -> cilobs, ci_upper_bs -> ciupbs, n_bootstrap -> nboot
    falsify_family: family_size -> famsz, at_floor -> atflr
    fips_sizes: opt_rand -> rnd
    fiscal_year_label: end_year -> endyear
    footprint_equivalents: car_km -> carkm, tree_months -> treemon
    frequency_table: pct_valid -> pctvalid
    friendly_download: target_path -> tpath
    hill_tail_index: x_min -> xmin, n_tail -> ntl
    hotspot_persistence: active_cells -> actcells, cells_for_half -> cellsforhalf,
      share_for_half -> shrforhalf, hot_cells -> hotcells, tied_in -> tiedin,
      tied_out -> tiedout, hot_share -> hotshr, jaccard_previous -> jacpre,
      periods_hot -> perhot, n_cells -> ncells, hot_k -> hotk
    hqc_sizes: encapsulation_key -> public, decapsulation_key -> secret,
      shared_secret -> shared
    kem_sizes: encapsulation_key -> public, decapsulation_key -> secret,
      shared_secret -> shared
    knox_test: space_lower -> spclo, space_upper -> spcup, time_lower -> tmlo,
      time_upper -> tmup
    life_table: at_risk -> atrisk, conf_lower -> conflo, conf_upper -> confup,
      life_table -> lifetbl
    mahalanobis_outliers: log_p_value -> logpvalue
    mcar_test: log_p_value -> logpvalue, n_patterns -> npat, n_used -> nused,
      n_vars -> nvars
    missingness_pattern: n_rows -> nrows, pct_rows -> pctrows
    missingness_summary: n_rows -> nrows
    morans_i: null_mean -> nullmean, null_sd -> nullsd, n_perm -> nperm
    parse_bands: open_lower -> openlo, open_upper -> openup
    plr_crossfit: k_folds -> kfol
    pollution_burden: attributable_cases -> attrcases, baseline_cases -> basecases,
      baseline_rate -> brate, exposure_mean -> expomean, reference_conc -> refconc,
      log_rr -> logrr
    pollution_burden_by_area: attributable_cases -> attrcases, baseline_cases -> basecases
    pollution_report_text: exit_status -> exitstat, exposure_csv -> expcsv,
      exposure_mean -> expomean, exposure_prevalence -> expoprev, paf_ci -> pafci
    prereg_check: declared_utc -> decutc, declared_not_reported -> decnotrep,
      reported_not_declared -> repnotdec
    profile_columns: n_zero -> nzero, n_negative -> nneg, n_infinite -> ninf
    published_bounds: rounding_kind -> rndkind, suppression_limit -> suplim
    rapl_available: rapl_dir -> rapldir
    region_coverage: has_unit -> hasunit, pop_share -> popshr, with_unit -> withunit,
      without_unit -> witunit, total_population -> totalpop, covered_population -> covpop,
      uncovered_population -> uncpop, covered_share -> covshr
    region_map_from_points: n_regions -> nreg
    scan_adjust: p_adjusted -> padj, scan_adjust -> scanadj
    stay_summary: total_days -> totaldays
    step_change: break_after -> breakafter, n_perm -> nperm
    stock_flow: flow_rate -> flowrate, stock_rate -> stkrate, people_change -> peochg,
      alos_change -> aloschg, days_change -> dayschg, adp_change -> adpchg,
      flow_rate_change -> flowratechg, stock_rate_change -> stkratechg,
      stock_flow -> stkflow
    survey_compare: conf_level -> conflvl
    survey_design: lonely_psu -> lonely
    survey_estimate: conf_level -> conflvl
    top_correlations: abs_correlation -> abscor
    trend_test: slope_lower -> slopelo, slope_upper -> slopeup,
      slope_ci_clamped -> slopecicla, conf_level -> conflvl
    wayback_save: max_captures -> maxcap
    yoy_bounds: env_change_lower -> envchglo, env_change_upper -> envchgup,
      env_pct_lower -> envpctlo, env_pct_upper -> envpctup, combined_pct_lower -> compctlo,
      combined_pct_upper -> compctup
    yoy_label: period_label -> perlbl
    rate: per_label -> perlbl, conf_level -> conflvl, min_count -> mincnt
    rate_change: previous_rate -> prerate, previous_count -> precnt,
      previous_population -> prepop, rate_ratio -> rateratio, pct_change -> pctchg,
      pct_lower -> pctlo, pct_upper -> pctup, rate_change -> ratechg
    share: conf_level -> conflvl
    yoy_summary: total_pct -> totalpct, cagr_pct -> cagrpct
    yoy: pct_change -> pctchg, pp_change -> ppchg, min_base -> minbase, pct_lower -> pctlo,
      pct_upper -> pctup, conf_level -> conflvl
