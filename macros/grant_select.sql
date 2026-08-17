{% macro grant_select(schema=target.schema, role=target.role) %}
        {% set sql %}
            grant usage on schema {{ schema }} to {{ role }} ;
            grant select on all tables in schema {{ schema }} to role {{ role }};
            grant select on all views in schema {{ schema }} to role {{ role }};
        {% endset %}

        {{log ('Grant Access' ~ target.schema ~ ' to role', info=true)}}
        {% do run_query(sql) %}
        {{log ('Priv Granted', info=true)}}
{% endmacro %}