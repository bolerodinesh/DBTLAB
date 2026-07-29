with

    -- Import CTEs
    customers as (select * from {{ source("jaffle_shop", "customers") }}),

    orders as (select * from {{ source("jaffle_shop", "orders") }}),

    payments as (select * from {{ source("stripe", "payment") }}),

    -- Logical CTEs
    payment_success as (
        select
            orderid as order_id,
            max(created) as payment_finalized_date,
            sum(amount) / 100.0 as total_amount_paid
        from payments
        where status <> 'fail'
        group by 1
    ),

    paid_orders as (
        select
            orders.id as order_id,
            orders.user_id as customer_id,
            orders.order_date as order_placed_at,
            orders.status as order_status,
            payment_success.total_amount_paid,
            payment_success.payment_finalized_date,
            customers.first_name as customer_first_name,
            customers.last_name as customer_last_name
        from orders
        left join payment_success on orders.id = payment_success.order_id
        left join customers on orders.user_id = customers.id
    ),


    customer_lifetime as (
        select p.order_id, sum(t2.total_amount_paid) as clv_bad
        from paid_orders p
        left join
            paid_orders t2
            on p.customer_id = t2.customer_id
            and p.order_id >= t2.order_id
        group by 1
        order by p.order_id
    ),

    -- Final CTE
    final as (
        select
            p.*,
            row_number() over (order by p.order_id) as transaction_seq,
            row_number() over (
                partition by customer_id order by p.order_id
            ) as customer_sales_seq,
            case
                when (rank() over (partition by customer_id order by order_placed_at, p.order_id) = 1)
                then 'new'
                else 'return'
            end as nvsr,
            customer_lifetime.clv_bad as customer_lifetime_value,
            first_value(p.order_placed_at) over (partition by customer_id order by order_placed_at, p.order_id asc) as fdos
        from paid_orders p
        left outer join customer_lifetime on customer_lifetime.order_id = p.order_id
        order by order_id
    )
-- Simple Select Statmen
select *
from final
